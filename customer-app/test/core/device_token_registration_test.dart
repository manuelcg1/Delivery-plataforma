import 'dart:async';
import 'package:delivery_customer/core/notifications/device_token_registration.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stop drains in-flight registration and rejects later refreshes',
      () async {
    final dio = Dio();
    final started = Completer<void>(), release = Completer<void>();
    final requests = <String>[];
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      requests.add(options.method);
      if (options.method == 'POST') {
        started.complete();
        await release.future;
      }
      handler.resolve(Response<void>(requestOptions: options, statusCode: 204));
    }));
    final registration = DeviceTokenRegistration(dio);
    final registering = registration.register('token', 'ANDROID');
    await started.future;
    final logout = () async {
      await registration.stop();
      await dio.delete<void>('/api/v1/device-tokens');
    }();
    await Future<void>.delayed(Duration.zero);
    expect(requests, ['POST']);
    release.complete();
    await Future.wait([registering, logout]);
    await registration.register('refreshed-token', 'ANDROID');
    expect(requests, ['POST', 'DELETE']);
  });
}
