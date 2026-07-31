import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  const SessionStore(this.storage);
  final FlutterSecureStorage storage;
  static const _access = 'access_token', _refresh = 'refresh_token';
  static final _sessionCleared = StreamController<void>.broadcast();
  static Stream<void> get sessionCleared => _sessionCleared.stream;
  Future<String?> accessToken() => storage.read(key: _access);
  Future<String?> refreshToken() => storage.read(key: _refresh);
  Future<void> save({required String accessToken, String? refreshToken}) async {
    await storage.write(key: _access, value: accessToken);
    if (refreshToken != null)
      await storage.write(key: _refresh, value: refreshToken);
  }

  Future<void> clear() async {
    await storage.deleteAll();
    _sessionCleared.add(null);
  }
}
