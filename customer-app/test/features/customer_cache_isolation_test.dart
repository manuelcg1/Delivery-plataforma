import 'dart:async';
import 'dart:convert';
import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/core/offline/offline_cache.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String accountToken(String tenant, String user) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({
              'tenantId': tenant,
              'userId': user
            }))).replaceAll('=', '')}.signature';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionStore store;
  late ApiClient api;
  late CommerceRepository repository;
  Object? failure;
  Completer<void>? gate;
  const order = {
    'id': 'order-a',
    'orderNumber': 'A-1',
    'status': 'PENDING',
    'total': 12,
    'currency': 'PEN',
    'createdAt': '2026-11-08'
  };
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    store = const SessionStore(FlutterSecureStorage());
    await store.save(accessToken: accountToken('tenant-a', 'user-a'));
    api = ApiClient('https://example.test', store);
    api.dio.interceptors.clear();
    failure = null;
    gate = null;
    api.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      await gate?.future;
      final error = failure;
      if (error is int) {
        handler.reject(DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: error),
            type: DioExceptionType.badResponse));
      } else if (error != null) {
        handler.reject(DioException(
            requestOptions: request, type: DioExceptionType.connectionError));
      } else {
        handler.resolve(Response(requestOptions: request, data: [order]));
      }
    }));
    repository = CommerceRepository(api);
  });
  test('same customer can read cached orders offline', () async {
    expect((await repository.orders()).single.id, 'order-a');
    failure = true;
    expect((await repository.orders()).single.id, 'order-a');
  });
  test('another user and tenant cannot read cached orders', () async {
    await repository.orders();
    failure = true;
    await store.save(accessToken: accountToken('tenant-a', 'user-b'));
    await expectLater(repository.orders(), throwsA(isA<DioException>()));
    await store.save(accessToken: accountToken('tenant-b', 'user-a'));
    await expectLater(repository.orders(), throwsA(isA<DioException>()));
  });
  test('authentication and server failures never use offline cache', () async {
    await repository.orders();
    for (final status in [401, 403, 500]) {
      failure = status;
      await expectLater(repository.orders(), throwsA(isA<DioException>()));
    }
  });
  test('logout removes customer caches', () async {
    await repository.orders();
    await store.clear();
    await store.save(accessToken: accountToken('tenant-a', 'user-a'));
    failure = true;
    await expectLater(repository.orders(), throwsA(isA<DioException>()));
    expect(await OfflineCache.read('orders:last'), isNull);
  });
  test('logout rejects an in-flight previous-session response', () async {
    gate = Completer<void>();
    final pending = repository.orders();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.clear();
    await store.save(accessToken: accountToken('tenant-a', 'user-b'));
    final rejected = expectLater(pending, throwsA(anything));
    gate!.complete();
    await rejected;
    failure = true;
    await expectLater(repository.orders(), throwsA(isA<DioException>()));
  });
  test('API origin is part of cache namespace', () async {
    await repository.orders();
    api.dio.options.baseUrl = 'https://another.test';
    failure = true;
    await expectLater(repository.orders(), throwsA(isA<DioException>()));
  });
}
