import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers.dart';
import '../../../../core/auth/session_store.dart';
import '../../data/courier_repository.dart';
import '../data/courier_tracking_repository.dart';
import '../domain/tracking_policy.dart';
import '../services/courier_location_permission_service.dart';
import '../services/courier_location_service.dart';

sealed class CourierTrackingState {
  const CourierTrackingState();
}

class TrackingIdle extends CourierTrackingState {
  const TrackingIdle();
}

class TrackingRequestingPermission extends CourierTrackingState {
  const TrackingRequestingPermission();
}

class TrackingStarting extends CourierTrackingState {
  const TrackingStarting();
}

class TrackingActive extends CourierTrackingState {
  const TrackingActive({this.lastSentAt, this.sending = false});
  final DateTime? lastSentAt;
  final bool sending;
}

class TrackingPaused extends CourierTrackingState {
  const TrackingPaused();
}

class TrackingPermissionDenied extends CourierTrackingState {
  const TrackingPermissionDenied({required this.permanently});
  final bool permanently;
}

class TrackingGpsDisabled extends CourierTrackingState {
  const TrackingGpsDisabled();
}

class TrackingOffline extends CourierTrackingState {
  const TrackingOffline(this.message);
  final String message;
}

class TrackingError extends CourierTrackingState {
  const TrackingError(this.message);
  final String message;
}

class TrackingStopped extends CourierTrackingState {
  const TrackingStopped();
}

final courierLocationPermissionServiceProvider =
    Provider<CourierLocationPermissionServiceContract>(
        (_) => CourierLocationPermissionService());
final courierTrackingRepositoryProvider = Provider(
  (ref) => CourierTrackingRepository(ref.watch(apiClientProvider)),
);
final courierLocationServiceProvider =
    Provider<CourierLocationServiceContract>((ref) {
  final service =
      CourierLocationService(ref.watch(courierTrackingRepositoryProvider));
  ref.onDispose(service.stop);
  return service;
});
final courierTrackingControllerProvider =
    NotifierProvider<CourierTrackingController, CourierTrackingState>(
  CourierTrackingController.new,
);

class CourierTrackingController extends Notifier<CourierTrackingState> {
  StreamSubscription<CourierLocationEvent>? _events;
  Future<bool>? _startOperation;
  String? _deliveryId;
  String? _status;

  CourierLocationServiceContract get _service =>
      ref.read(courierLocationServiceProvider);
  CourierLocationPermissionServiceContract get _permissions =>
      ref.read(courierLocationPermissionServiceProvider);

  @override
  CourierTrackingState build() {
    final sessionSubscription =
        SessionStore.sessionCleared.listen((_) => unawaited(onSessionEnded()));
    ref.onDispose(sessionSubscription.cancel);
    ref.onDispose(() => _events?.cancel());
    return const TrackingIdle();
  }

  Future<bool> startTracking({
    String? deliveryId,
    String status = 'PICKED_UP',
  }) async {
    if (_service.isActive && _deliveryId == deliveryId) {
      state = TrackingActive(
        lastSentAt: state is TrackingActive
            ? (state as TrackingActive).lastSentAt
            : null,
      );
      return true;
    }
    if (_service.isActive) await stopTracking();
    final currentStart = _startOperation;
    if (currentStart != null) return currentStart;
    final operation = _startTracking(deliveryId: deliveryId, status: status);
    _startOperation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_startOperation, operation)) _startOperation = null;
    }
  }

  Future<bool> _startTracking({
    required String? deliveryId,
    required String status,
  }) async {
    _debug('start delivery=$deliveryId status=$status');
    state = const TrackingRequestingPermission();
    final permission = await _permissions.ensurePermission();
    switch (permission) {
      case CourierLocationPermissionResult.gpsDisabled:
        state = const TrackingGpsDisabled();
        return false;
      case CourierLocationPermissionResult.denied:
        state = const TrackingPermissionDenied(permanently: false);
        return false;
      case CourierLocationPermissionResult.permanentlyDenied:
        state = const TrackingPermissionDenied(permanently: true);
        return false;
      case CourierLocationPermissionResult.granted:
        break;
    }
    state = const TrackingStarting();
    try {
      if (deliveryId == null || deliveryId.isEmpty) {
        state = const TrackingError('No se pudo asociar el GPS a una entrega.');
        return false;
      }
      _deliveryId = deliveryId;
      _status = status;
      await _events?.cancel();
      _events = _service.events.listen(_onEvent);
      final started = await _service.start(deliveryId: deliveryId);
      if (!started) {
        state = const TrackingError('No se pudo iniciar el GPS.');
        return false;
      }
      state = const TrackingActive();
      await _persist(active: true);
      return true;
    } catch (error) {
      await _service.stop();
      state = TrackingError('No se pudo iniciar la ubicación: $error');
      return false;
    }
  }

  Future<void> stopTracking({bool sendFinal = false}) async {
    if (sendFinal && _service.isActive) {
      try {
        await _service.sendFinalLocation();
      } catch (_) {
        // Delivery completion must still release the foreground service.
      }
    }
    await _service.stop();
    await _events?.cancel();
    _events = null;
    _deliveryId = null;
    _status = null;
    await _persist(active: false);
    state = const TrackingStopped();
    _debug('tracking stopped');
  }

  Future<void> sendFinalLocation() async {
    if (_service.isActive) await _service.sendFinalLocation();
  }

  Future<void> onSessionEnded() => stopTracking();

  Future<void> pauseTracking() async {
    await _service.pause();
    state = const TrackingPaused();
  }

  Future<void> resumeTracking() async {
    if (!_service.isActive) {
      await startTracking(
          deliveryId: _deliveryId, status: _status ?? 'PICKED_UP');
      return;
    }
    state = const TrackingStarting();
    await _service.resume();
  }

  Future<void> synchronizeDelivery(CourierDelivery delivery) async {
    _debug('active delivery=${delivery.id} status=${delivery.status}');
    _status = delivery.status;
    if (shouldStopTracking(delivery.status)) {
      await stopTracking();
    } else if (shouldContinueTracking(delivery.status) && !_service.isActive) {
      await startTracking(deliveryId: delivery.id, status: delivery.status);
    }
  }

  Future<void> restoreFromBackend(List<CourierDelivery> deliveries) async {
    final trackable = deliveries
        .where((delivery) => shouldContinueTracking(delivery.status)).toList();
    final preferences = await SharedPreferences.getInstance();
    final persistedId = preferences.getString('courier.deliveryId');
    final persisted = trackable.where((delivery) => delivery.id == persistedId).firstOrNull;
    final active = persisted ?? (trackable.length == 1 ? trackable.single : null);
    if (active == null) {
      if (_service.isActive) await stopTracking();
      if (trackable.length > 1) {
        state = const TrackingError('Selecciona una entrega para compartir su ubicación.');
      }
      return;
    }
    await startTracking(deliveryId: active.id, status: active.status);
  }

  Future<void> openSettings() async {
    final current = state;
    if (current is TrackingGpsDisabled) {
      await _permissions.openLocationSettings();
    } else {
      await _permissions.openAppSettings();
    }
  }

  void _onEvent(CourierLocationEvent event) {
    switch (event.type) {
      case CourierLocationEventType.sending:
        state = TrackingActive(
          lastSentAt: state is TrackingActive
              ? (state as TrackingActive).lastSentAt
              : null,
          sending: true,
        );
      case CourierLocationEventType.sent:
        state = TrackingActive(lastSentAt: event.sentAt);
        unawaited(_persist(active: true, lastSentAt: event.sentAt));
      case CourierLocationEventType.offline:
        state = TrackingOffline(event.message ?? 'Sin conexión.');
      case CourierLocationEventType.error:
        state = TrackingError(event.message ?? 'Error de ubicación.');
    }
  }

  Future<void> _persist({required bool active, DateTime? lastSentAt}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('courier.trackingActive', active);
    if (!active) {
      await preferences.remove('courier.deliveryId');
      await preferences.remove('courier.lastKnownStatus');
      await preferences.remove('courier.lastLocationSentAt');
      return;
    }
    if (_deliveryId != null) {
      await preferences.setString('courier.deliveryId', _deliveryId!);
    }
    if (_status != null) {
      await preferences.setString('courier.lastKnownStatus', _status!);
    }
    if (lastSentAt != null) {
      await preferences.setString(
        'courier.lastLocationSentAt',
        lastSentAt.toUtc().toIso8601String(),
      );
    }
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[CourierTracking] $message');
  }
}
