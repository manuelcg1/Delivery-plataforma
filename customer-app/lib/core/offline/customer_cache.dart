import 'dart:convert';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../auth/session_store.dart';
import 'offline_cache.dart';

/// Cache boundaries are an additional UI safeguard, never authorization.
class CustomerCache {
  CustomerCache._(this.api, this.scope, this.epoch, this.origin);
  final ApiClient api;
  final String? scope;
  final int epoch;
  final String origin;
  static Future<CustomerCache> capture(ApiClient api) async => CustomerCache._(
      api,
      await api.store.identityScope(),
      SessionStore.sessionEpoch,
      api.dio.options.baseUrl);
  Future<void> check() async {
    if (SessionStore.sessionEpoch != epoch ||
        api.dio.options.baseUrl != origin ||
        await api.store.identityScope() != scope) {
      throw StateError('La sesión cambió. Vuelve a cargar los datos.');
    }
  }

  String _key(String key) =>
      'customer:v2:${base64Url.encode(utf8.encode('$origin|$scope'))}:$key';
  Future<void> write(String key, Object value) async {
    await check();
    if (scope != null) {
      try {
        await OfflineCache.write(_key(key), value);
      } catch (_) {}
    }
    await check();
  }

  Future<dynamic> read(String key) async {
    await check();
    if (scope == null) return null;
    dynamic value;
    try {
      value = await OfflineCache.read(_key(key));
    } catch (_) {}
    await check();
    return value;
  }

  static bool permitsFallback(Object error) =>
      error is DioException &&
      const {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type);
}
