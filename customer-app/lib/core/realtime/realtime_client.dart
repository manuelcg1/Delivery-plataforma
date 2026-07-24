import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../auth/session_store.dart';

class RealtimeEvent {
  const RealtimeEvent(this.type, this.payload);
  final String type;
  final Map<String, dynamic> payload;
}

class RealtimeClient {
  RealtimeClient(this.baseUrl, this.store);
  final String baseUrl;
  final SessionStore store;
  StompClient? _client;
  final _events = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _events.stream;
  Future<void> connect(
      {required String tenantId, required String deliveryId}) async {
    await _connect('/topic/tenants/$tenantId/deliveries/$deliveryId');
  }

  Future<void> connectAudience({
    required String tenantId,
    required String audience,
  }) async {
    await _connect('/topic/tenants/$tenantId/$audience');
  }

  Future<void> _connect(String destination) async {
    disconnect();
    final token = await store.accessToken();
    final headers = {'Authorization': 'Bearer $token'};
    _client = StompClient(
        config: StompConfig(
            url: '$baseUrl/api/v1/realtime',
            stompConnectHeaders: headers,
            webSocketConnectHeaders: headers,
            reconnectDelay: const Duration(seconds: 5),
            heartbeatIncoming: const Duration(seconds: 10),
            heartbeatOutgoing: const Duration(seconds: 10),
            onConnect: (frame) {
              _client?.subscribe(
                  destination: destination,
                  callback: (frame) {
                    if (frame.body == null) return;
                    final json =
                        jsonDecode(frame.body!) as Map<String, dynamic>;
                    _events.add(RealtimeEvent(
                        json['event']?.toString() ?? 'Unknown',
                        (json['payload'] as Map?)?.cast<String, dynamic>() ??
                            {}));
                  });
            },
            onWebSocketError: (_) {},
            onStompError: (_) {}));
    _client!.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }

  Future<void> dispose() async {
    disconnect();
    await _events.close();
  }
}
