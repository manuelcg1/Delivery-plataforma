import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Serializes token refreshes and lets logout drain writes before deactivation.
class DeviceTokenRegistration {
  DeviceTokenRegistration(this.dio);
  final Dio dio;
  Future<void> _pending = Future<void>.value();
  bool _stopped = false;
  bool registered = false;

  Future<void> register(String token, String platform) {
    _pending = _pending.then((_) async {
      if (_stopped) return;
      registered = false;
      try {
        await dio.post<void>('/api/v1/device-tokens', data: {
          'token': token,
          'platform': platform,
        });
        registered = true;
      } catch (error) {
        debugPrint(
            'No se pudo registrar el dispositivo push: ${error.runtimeType}');
      }
    });
    return _pending;
  }

  Future<void> stop() async {
    _stopped = true;
    await _pending;
  }
}
