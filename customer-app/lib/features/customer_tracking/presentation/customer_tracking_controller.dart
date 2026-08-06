import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/realtime/realtime_client.dart';
import '../data/customer_tracking_repository.dart';
import '../domain/customer_tracking_event.dart';
import '../domain/customer_tracking_response.dart';

const terminalDeliveryStatuses = {
  'DELIVERED',
  'FAILED',
  'CANCELLED',
  'REJECTED',
  'EXPIRED',
};
const trackableDeliveryStatuses = {
  'PICKED_UP',
  'IN_TRANSIT',
  'ARRIVED_AT_CUSTOMER',
};

class CustomerTrackingState {
  const CustomerTrackingState({
    this.loading = false,
    this.connected = false,
    this.reconnecting = false,
    this.polling = false,
    this.trackingActive = false,
    this.stale = true,
    this.error,
    this.tracking,
    this.arrivalNoticeId,
  });

  final bool loading, connected, reconnecting, polling, trackingActive, stale;
  final String? error;
  final CustomerOrderTracking? tracking;
  final String? arrivalNoticeId;

  CustomerTrackingState copyWith({
    bool? loading,
    bool? connected,
    bool? reconnecting,
    bool? polling,
    bool? trackingActive,
    bool? stale,
    String? error,
    bool clearError = false,
    CustomerOrderTracking? tracking,
    String? arrivalNoticeId,
  }) =>
      CustomerTrackingState(
        loading: loading ?? this.loading,
        connected: connected ?? this.connected,
        reconnecting: reconnecting ?? this.reconnecting,
        polling: polling ?? this.polling,
        trackingActive: trackingActive ?? this.trackingActive,
        stale: stale ?? this.stale,
        error: clearError ? null : error ?? this.error,
        tracking: tracking ?? this.tracking,
        arrivalNoticeId: arrivalNoticeId ?? this.arrivalNoticeId,
      );
}

final customerTrackingRepositoryProvider =
    Provider<CustomerTrackingRepositoryContract>(
  (ref) => CustomerTrackingRepository(
    ref.watch(apiClientProvider),
    ref.watch(customerRealtimeClientProvider),
  ),
);

final customerOrderTrackingControllerProvider = StateNotifierProvider
    .autoDispose
    .family<CustomerOrderTrackingController, CustomerTrackingState, String>(
        (ref, orderId) {
  final controller = CustomerOrderTrackingController(
    ref.watch(customerTrackingRepositoryProvider),
  );
  ref.onDispose(controller.stop);
  Future.microtask(() => controller.start(orderId));
  return controller;
});

class CustomerOrderTrackingController
    extends StateNotifier<CustomerTrackingState> {
  CustomerOrderTrackingController(this.repository)
      : super(const CustomerTrackingState());

  final CustomerTrackingRepositoryContract repository;
  CustomerTrackingSubscription? _realtime;
  StreamSubscription<CustomerTrackingEvent>? _events;
  StreamSubscription<RealtimeConnectionState>? _connections;
  Timer? _polling;
  String? _orderId;
  bool _started = false;
  bool _refreshing = false;

  Future<void> start(String orderId) async {
    if (_started && _orderId == orderId) return;
    await stop();
    _started = true;
    _orderId = orderId;
    state = const CustomerTrackingState(loading: true, reconnecting: true);
    try {
      _realtime = await repository.subscribeToTracking(orderId);
      _events =
          _realtime!.events.listen(_applyEvent, onError: _onRealtimeError);
      _connections = _realtime!.connectionStates.listen(_connectionChanged);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        loading: false,
        reconnecting: false,
        error: repository.errorMessage(error),
      );
    }
  }

  Future<void> refresh() async {
    final orderId = _orderId;
    if (orderId == null || _refreshing) return;
    _refreshing = true;
    try {
      final tracking = await repository.getTracking(orderId);
      if (!_started || _orderId != orderId) return;
      final currentGps = state.tracking?.location?.gpsTimestamp;
      final incomingGps = tracking.location?.gpsTimestamp;
      final selected = currentGps != null &&
              (incomingGps == null || !incomingGps.isAfter(currentGps))
          ? state.tracking!
          : tracking;
      state = state.copyWith(
        loading: false,
        tracking: selected,
        trackingActive: selected.trackingActive,
        stale: selected.stale,
        clearError: true,
      );
      if (!selected.trackingActive ||
          terminalDeliveryStatuses.contains(selected.deliveryStatus)) {
        await _stopTransport();
      }
    } catch (error) {
      if (_started) {
        state = state.copyWith(
            loading: false, error: repository.errorMessage(error));
      }
    } finally {
      _refreshing = false;
    }
  }

  void _applyEvent(CustomerTrackingEvent event) {
    if (!_started || event.orderId != _orderId) return;
    final current = state.tracking;
    if (current == null) {
      unawaited(refresh());
      return;
    }
    final nextGps = event.location?.gpsTimestamp;
    final currentGps = current.location?.gpsTimestamp;
    if (nextGps != null && currentGps != null && !nextGps.isAfter(currentGps))
      return;
    final terminal = event.type == 'TRACKING_STOPPED' ||
        terminalDeliveryStatuses.contains(event.deliveryStatus);
    final next = current.apply(
      status: event.deliveryStatus,
      nextLocation: event.location,
      active:
          !terminal && trackableDeliveryStatuses.contains(event.deliveryStatus),
      publishedAt: event.publishedAt,
    );
    state = state.copyWith(
      tracking: next,
      trackingActive: next.trackingActive,
      stale: next.stale,
      clearError: true,
      arrivalNoticeId: event.type == 'COURIER_ARRIVED'
          ? (event.deliveryId ?? event.publishedAt.toIso8601String())
          : state.arrivalNoticeId,
    );
    if (terminal) unawaited(_stopTransport());
  }

  void _connectionChanged(RealtimeConnectionState value) {
    if (!_started) return;
    if (value == RealtimeConnectionState.connected) {
      final wasDisconnected = !state.connected;
      _polling?.cancel();
      _polling = null;
      state =
          state.copyWith(connected: true, reconnecting: false, polling: false);
      if (wasDisconnected) unawaited(refresh());
    } else if (value == RealtimeConnectionState.disconnected ||
        value == RealtimeConnectionState.error) {
      state = state.copyWith(connected: false, reconnecting: true);
      _startPolling();
    }
  }

  void _onRealtimeError(Object _) {
    if (_started) {
      state = state.copyWith(connected: false, reconnecting: true);
      _startPolling();
    }
  }

  void _startPolling() {
    if (_polling != null || !state.trackingActive && state.tracking != null)
      return;
    _polling = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    state = state.copyWith(polling: true);
  }

  Future<void> _stopTransport() async {
    _polling?.cancel();
    _polling = null;
    await _events?.cancel();
    _events = null;
    await _connections?.cancel();
    _connections = null;
    await _realtime?.cancel();
    _realtime = null;
    if (mounted)
      state =
          state.copyWith(connected: false, reconnecting: false, polling: false);
  }

  Future<void> stop() async {
    _started = false;
    _orderId = null;
    await _stopTransport();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
