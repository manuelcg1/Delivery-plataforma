import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  const SessionStore(this.storage);
  final FlutterSecureStorage storage;
  static int sessionEpoch = 0;
  Future<String?> identityScope() async {
    try {
      final token = await accessToken();
      if (token == null || token.split('.').length != 3) return null;
      final claims = jsonDecode(utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1]))))
          as Map<String, dynamic>;
      final tenant = claims['tenantId'],
          user = claims['userId'] ?? claims['sub'];
      return tenant is String &&
              tenant.isNotEmpty &&
              user is String &&
              user.isNotEmpty
          ? '$tenant/$user'
          : null;
    } catch (_) {
      return null;
    }
  }

  static const _access = 'access_token', _refresh = 'refresh_token';
  static final _sessionCleared = StreamController<void>.broadcast();
  static Stream<void> get sessionCleared => _sessionCleared.stream;
  Future<String?> accessToken() => storage.read(key: _access);
  Future<String?> refreshToken() => storage.read(key: _refresh);
  Future<DateTime?> accessTokenExpiresAt() async {
    final token = await accessToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = (payload as Map<String, dynamic>)['exp'];
      return exp is num
          ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> needsRefresh(
      {Duration threshold = const Duration(minutes: 2)}) async {
    final expires = await accessTokenExpiresAt();
    return expires == null ||
        !expires.isAfter(DateTime.now().toUtc().add(threshold));
  }

  Future<void> save({required String accessToken, String? refreshToken}) async {
    await storage.write(key: _access, value: accessToken);
    if (refreshToken != null)
      await storage.write(key: _refresh, value: refreshToken);
  }

  Future<void> clear() async {
    sessionEpoch++;
    await storage.deleteAll();
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys().toList()) {
        if (key.startsWith('customer:v2:') ||
            key == 'cart:last' ||
            key == 'orders:last' ||
            key.startsWith('tracking:')) await preferences.remove(key);
      }
    } catch (_) {}
    _sessionCleared.add(null);
  }
}
