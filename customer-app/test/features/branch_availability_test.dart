import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:dio/dio.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('availability preserves next opening instant and schedule', () {
    final availability = BranchAvailability.fromJson({
      'branchId': 'b',
      'open': false,
      'status': 'OUTSIDE_BUSINESS_HOURS',
      'timezone': 'America/Lima',
      'nextOpeningAt': '2026-11-09T09:00:00-05:00',
      'currentSchedule': {'opensAt': '09:00', 'closesAt': '18:00'},
    });
    expect(availability.nextOpeningAt, DateTime.parse('2026-11-09T14:00:00Z'));
    expect(availability.currentSchedule?['opensAt'], '09:00');
  });
  test('coverage hours rejection displays closure', () {
    expect(coverageMessageForCode('OUTSIDE_BUSINESS_HOURS'),
        'Fuera de horario de atención');
  });
  test('availability is fetched fresh and preserves legacy open status',
      () async {
    final api = ApiClient(
        'https://example.test', const SessionStore(FlutterSecureStorage()));
    api.dio.interceptors.clear();
    var calls = 0;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      calls++;
      expect(request.path, '/api/v1/customer/branches/b/availability');
      handler.resolve(Response(requestOptions: request, data: {
        'branchId': 'b',
        'open': calls == 1,
        'status': calls == 1 ? 'UNCONFIGURED' : 'CLOSED',
        'timezone': 'America/Lima',
        'nextOpeningAt': null,
        'currentSchedule': null,
      }));
    }));
    final repository = CustomerRepository(api);
    expect((await repository.availability('b')).open, isTrue);
    final closed = await repository.availability('b');
    expect(closed.open, isFalse);
    expect(closed.status, 'CLOSED');
    expect(closed.timezone, 'America/Lima');
    expect(closed.nextOpeningAt, isNull);
    expect(calls, 2);
  });
  test('availability network failure is never treated as open', () async {
    final api = ApiClient(
        'https://example.test', const SessionStore(FlutterSecureStorage()));
    api.dio.interceptors.clear();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      handler.reject(DioException(requestOptions: request));
    }));
    await expectLater(CustomerRepository(api).availability('b'),
        throwsA(isA<DioException>()));
  });
}
