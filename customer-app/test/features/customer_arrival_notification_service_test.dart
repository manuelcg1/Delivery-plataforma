import 'dart:async';
import 'dart:convert';
import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/core/notifications/push_notification_service.dart';
import 'package:delivery_customer/features/customer_tracking/notifications/arrival_notice_coordinator.dart';
import 'package:delivery_customer/features/customer_tracking/notifications/customer_arrival_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePush extends PushNotificationService {
  FakePush(super.api);
  bool initialized = false;
  Future<void> Function(Map<String, dynamic>)? opened;
  @override
  Future<void> initialize(
      {required Future<void> Function(Map<String, dynamic>) onMessage,
      required Future<void> Function(Map<String, dynamic>) onOpened}) async {
    initialized = true;
    opened = onOpened;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  test('cold local launch initializes push before navigation and uses orderId',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getNotificationAppLaunchDetails')
        return {
          'notificationLaunchedApp': true,
          'notificationResponse': {
            'notificationResponseType': 0,
            'payload': jsonEncode({
              'type': 'COURIER_ARRIVED',
              'orderId': 'order-42',
              'deliveryId': 'delivery-9'
            })
          },
        };
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final api = ApiClient(
        'https://example.test', const SessionStore(FlutterSecureStorage()));
    final push = FakePush(api);
    final opened = Completer<void>(), closeRoute = Completer<void>();
    String? target;
    final service = CustomerArrivalNotificationService(
        api, ArrivalNoticeCoordinator(scope: 'tenant:user'), push: push,
        onOpenOrder: (id) async {
      target = id;
      opened.complete();
      await closeRoute.future;
    });
    final initializing = service.initialize();
    await opened.future.timeout(const Duration(seconds: 5));
    expect(push.initialized, isTrue);
    expect(target, 'order-42');
    closeRoute.complete();
    await initializing;
    await service.dispose();
    await push.opened!({'type': 'COURIER_ARRIVED', 'orderId': 'other'});
    expect(target, 'order-42');
  });
}
