import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../auth/session_store.dart';

class RealtimeEvent {
  const RealtimeEvent(this.type, this.payload);
  final String type;
  final Map<String, dynamic> payload;
}

enum RealtimeConnectionState { connecting, connected, disconnected, error }

class RealtimeDestinationSubscription {
  RealtimeDestinationSubscription(
      this.events, this.connectionStates, this.cancel);
  final Stream<Map<String, dynamic>> events;
  final Stream<RealtimeConnectionState> connectionStates;
  final Future<void> Function() cancel;
}

class RealtimeClient {
  RealtimeClient(this.url, this.store);

  final String url;
  final SessionStore store;
  StompClient? _client;
  bool _connected = false;
  bool _manualDisconnect = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _states = StreamController<RealtimeConnectionState>.broadcast();
  final Map<String, StreamController<Map<String, dynamic>>> _destinations = {};
  final Map<String, String> _destinationNames = {};
  final Map<String, StompUnsubscribe> _unsubscribers = {};

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<RealtimeConnectionState> get connectionStates => _states.stream;

  Future<void> connect(
          {required String tenantId, required String deliveryId}) =>
      _replaceLegacyDestination(
          '/topic/tenants/$tenantId/deliveries/$deliveryId');

  Future<void> connectAudience(
          {required String tenantId, required String audience}) =>
      _replaceLegacyDestination('/topic/tenants/$tenantId/$audience');

  Future<void> _replaceLegacyDestination(String destination) async {
    const legacy = '__legacy__';
    await _removeDestination(legacy);
    final controller = StreamController<Map<String, dynamic>>();
    _destinations[legacy] = controller;
    _destinationNames[legacy] = destination;
    controller.stream.listen((json) {
      _events.add(RealtimeEvent(
        json['event']?.toString() ?? json['type']?.toString() ?? 'Unknown',
        (json['payload'] as Map?)?.cast<String, dynamic>() ?? json,
      ));
    });
    await _ensureConnected();
    _subscribeKey(legacy, destination);
  }

  Future<RealtimeDestinationSubscription> subscribe(String destination) async {
    if (!RegExp(r'^/user/queue/orders/[0-9a-fA-F-]{36}/tracking$')
        .hasMatch(destination)) {
      throw ArgumentError.value(
          destination, 'destination', 'Destino STOMP no permitido');
    }
    final controller = StreamController<Map<String, dynamic>>();
    final key = 'tracking:$destination';
    await _removeDestination(key);
    _destinations[key] = controller;
    _destinationNames[key] = destination;
    await _ensureConnected();
    _subscribeKey(key, destination);
    return RealtimeDestinationSubscription(
      controller.stream,
      connectionStates,
      () => _removeDestination(key),
    );
  }

  Future<void> _ensureConnected() async {
    if (_client != null) return;
    final token = await store.accessToken();
    if (token == null || token.isEmpty)
      throw StateError('Sesión no disponible');
    final headers = {'Authorization': 'Bearer $token'};
    _states.add(RealtimeConnectionState.connecting);
    late final StompClient connection;
    connection = StompClient(
      config: StompConfig(
        url: url,
        stompConnectHeaders: headers,
        webSocketConnectHeaders: headers,
        reconnectDelay: Duration.zero,
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (_) {
          if (!identical(_client, connection)) return;
          _connected = true;
          _reconnectAttempt = 0;
          _states.add(RealtimeConnectionState.connected);
          final entries = _destinations.keys.toList();
          for (final key in entries) {
            final destination = _destinationNames[key];
            if (destination != null) _subscribeKey(key, destination);
          }
        },
        onWebSocketDone: () {
          if (!identical(_client, connection)) return;
          _connected = false;
          _client = null;
          _unsubscribers.clear();
          _states.add(RealtimeConnectionState.disconnected);
          _scheduleReconnect();
        },
        onWebSocketError: (_) {
          if (!identical(_client, connection)) return;
          _connected = false;
          _client = null;
          _states.add(RealtimeConnectionState.error);
          _scheduleReconnect();
        },
        onStompError: (_) => _states.add(RealtimeConnectionState.error),
      ),
    );
    _client=connection;
    connection.activate();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _destinations.isEmpty || _reconnectTimer != null) {
      return;
    }
    const delays = [1, 2, 5, 10, 30];
    final delay = delays[math.min(_reconnectAttempt, delays.length - 1)];
    _reconnectAttempt++;
    _client = null;
    _unsubscribers.clear();
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      _reconnectTimer = null;
      if (_destinations.isEmpty || _manualDisconnect) return;
      try {
        await _ensureConnected();
      } catch (_) {
        _states.add(RealtimeConnectionState.error);
        _scheduleReconnect();
      }
    });
  }

  void _subscribeKey(String key, String destination) {
    final connection=_client;
    if (!_connected || connection==null || _unsubscribers.containsKey(key)) return;
    _unsubscribers[key] = connection.subscribe(
      destination: destination,
      callback: (frame) {
        if (frame.body == null || !_destinations.containsKey(key)) return;
        final decoded = jsonDecode(frame.body!);
        if (decoded is Map) {
          _destinations[key]!.add(decoded.cast<String, dynamic>());
        }
      },
    );
  }

  Future<void> _removeDestination(String key) async {
    _unsubscribers.remove(key)?.call();
    _destinationNames.remove(key);
    await _destinations.remove(key)?.close();
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _client?.deactivate();
    _client = null;
    _connected = false;
    _unsubscribers.clear();
    _manualDisconnect = false;
  }

  Future<void> reconnect() async {
    if(_destinations.isEmpty) return;
    _manualDisconnect=true;
    _reconnectTimer?.cancel();
    _reconnectTimer=null;
    final stale=_client;
    _client=null;
    _connected=false;
    _unsubscribers.clear();
    stale?.deactivate();
    _manualDisconnect=false;
    await _ensureConnected();
  }

  Future<void> dispose() async {
    disconnect();
    for (final controller in _destinations.values) {
      await controller.close();
    }
    _destinations.clear();
    await _events.close();
    await _states.close();
  }
}
