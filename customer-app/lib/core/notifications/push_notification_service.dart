import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import '../api/api_client.dart';
import 'device_token_registration.dart';

/// Shared Firebase lifecycle; feature services decide what each message means.
class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService(this.api)
      : _registration = DeviceTokenRegistration(api.dio) {
    _active.add(this);
  }
  final ApiClient api;
  final DeviceTokenRegistration _registration;
  static final _active = <PushNotificationService>{};
  StreamSubscription<RemoteMessage>? _messages;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<String>? _tokens;
  bool _disposed = false;

  Future<void> initialize({
    required Future<void> Function(Map<String, dynamic>) onMessage,
    required Future<void> Function(Map<String, dynamic>) onOpened,
  }) async {
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    try {
      await Firebase.initializeApp();
      if (_disposed) return;
      _messages = FirebaseMessaging.onMessage.listen((message) {
        if (!_disposed) unawaited(_guard(() => onMessage(message.data)));
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (!_disposed) unawaited(_guard(() => onOpened(message.data)));
      });
      _tokens = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        if (!_disposed) unawaited(_register(token));
      });
      await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, provisional: false);
      if (_disposed) return;
      await _registerCurrent();
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (!_disposed && initial != null) await onOpened(initial.data);
    } catch (error) {
      debugPrint(
          'No se pudo inicializar el servicio push: ${error.runtimeType}');
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('No se pudo procesar el aviso push: ${error.runtimeType}');
    }
  }

  Future<void> _registerCurrent() async {
    await _guard(() async {
      final token = await FirebaseMessaging.instance.getToken();
      if (!_disposed && token != null) await _register(token);
    });
  }

  Future<void> _register(String token) =>
      _registration.register(token, Platform.isIOS ? 'IOS' : 'ANDROID');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed &&
        !_registration.registered &&
        state == AppLifecycleState.resumed) {
      unawaited(_registerCurrent());
    }
  }

  static Future<void> unregisterCurrent(ApiClient api) async {
    for (final service
        in _active.where((s) => identical(s.api, api)).toList()) {
      await service.dispose();
    }
    try {
      await Firebase.initializeApp();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null)
        await api.dio.delete<void>('/api/v1/device-tokens', data: {
          'token': token,
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
        });
    } catch (error) {
      debugPrint(
          'No se pudo desactivar el token FCM al cerrar sesión: ${error.runtimeType}');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await _messages?.cancel();
    await _opened?.cancel();
    await _tokens?.cancel();
    await _registration.stop();
    _active.remove(this);
  }
}
