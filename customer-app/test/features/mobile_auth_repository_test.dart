import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('mobile login sends credentials without tenant', () async {
    const store = SessionStore(FlutterSecureStorage());
    final api = ApiClient('https://example.test', store);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/api/v1/auth/login-mobile');
      expect(options.data,
          {'email': 'ana@example.com', 'password': 'password123'});
      handler.resolve(Response(requestOptions: options, data: {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'user': {
          'id': '1',
          'firstName': 'Ana',
          'tenant': {'id': 't', 'code': 'server'},
          'roles': ['CUSTOMER']
        },
      }));
    }));
    await AuthRepository(api, store).login(
        tenantCode: 'ignored',
        email: 'ana@example.com',
        password: 'password123');
    expect(await store.accessToken(), 'access');
  });
  test('courier registration sends profile and phone without storing session',
      () async {
    const store = SessionStore(FlutterSecureStorage());
    final api = ApiClient('https://example.test', store);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/api/v1/auth/register-mobile');
      expect(options.data, {
        'firstName': 'Ana',
        'lastName': 'Perez',
        'email': 'ana@example.com',
        'password': 'password123',
        'phone': '+51 987-654-321',
        'profile': 'COURIER'
      });
      handler.resolve(Response(requestOptions: options, data: {
        'pendingApproval': true,
        'message': 'Pendiente de activación'
      }));
    }));
    final result = await AuthRepository(api, store).register(
        firstName: 'Ana',
        lastName: 'Perez',
        email: 'ana@example.com',
        password: 'password123',
        phone: '+51 987-654-321',
        profile: 'COURIER');
    expect(result.pendingApproval, isTrue);
    expect(result.message, 'Pendiente de activación');
    expect(await store.accessToken(), isNull);
    expect(await store.refreshToken(), isNull);
  });
}
