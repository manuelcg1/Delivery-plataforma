import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'fetches current merchant Yape each time and declares the version without capture',
      () async {
    final api = ApiClient(
        'https://example.test', const SessionStore(FlutterSecureStorage()));
    api.dio.interceptors.clear();
    final requests = <RequestOptions>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      handler.resolve(Response(
          requestOptions: request,
          data: request.method == 'GET'
              ? {
                  'enabled': true,
                  'phone': '999888777',
                  'holderName': 'Ana',
                  'qrUrl': 'https://example.test/qr',
                  'version': 'v1'
                }
              : {'status': 'PENDING'}));
    }));
    final repository = CommerceRepository(api);
    await repository.yapeSettings('merchant');
    await repository.yapeSettings('merchant');
    await repository.payYape('order', 'v1');
    expect(requests.map((r) => r.path), [
      '/api/v1/customer/checkout/merchants/merchant/yape',
      '/api/v1/customer/checkout/merchants/merchant/yape',
      '/api/v1/orders/order/payments',
    ]);
    expect(requests.last.data, {
      'paymentMethod': 'YAPE',
      'customerDeclared': true,
      'yapeSettingsVersion': 'v1'
    });
    expect(requests.last.headers['Idempotency-Key'], isNotEmpty);
  });
}
