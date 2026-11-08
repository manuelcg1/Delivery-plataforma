import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../core/api/api_client.dart';
import '../../../core/notifications/push_notification_service.dart';
import 'arrival_notice_coordinator.dart';

class CustomerArrivalNotificationService {
  CustomerArrivalNotificationService(ApiClient api, this.coordinator,
      {required this.onOpenOrder, PushNotificationService? push})
      : _push = push ?? PushNotificationService(api);
  final ArrivalNoticeCoordinator coordinator;
  final Future<void> Function(String orderId) onOpenOrder;
  final PushNotificationService _push;
  final _local = FlutterLocalNotificationsPlugin();
  bool _disposed = false;
  static const channel = AndroidNotificationChannel(
    arrivalChannel,
    'Llegada del pedido',
    description: 'Avisos cuando el repartidor llega al destino',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    await _local.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings()),
        onDidReceiveNotificationResponse: (response) async {
      if (response.payload != null) {
        await _open(
            (jsonDecode(response.payload!) as Map).cast<String, dynamic>());
      }
    });
    if (_disposed) return;
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
    await android?.requestNotificationsPermission();
    if (_disposed) return;
    await _push.initialize(onMessage: coordinator.receive, onOpened: _open);
    if (_disposed) return;
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload != null) {
      await _open((jsonDecode(launch!.notificationResponse!.payload!) as Map)
          .cast<String, dynamic>());
    }
  }

  Future<void> _open(Map<String, dynamic> data) async {
    final orderId = data['orderId']?.toString();
    if (!_disposed &&
        data['type'] == arrivalEvent &&
        orderId != null &&
        orderId.isNotEmpty) {
      await onOpenOrder(orderId);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _push.dispose();
  }

  /// Data-only fallback. Notification payloads are displayed by the OS instead.
  static Future<void> showBackground(Map<String, dynamic> data) async {
    final deliveryId = data['deliveryId']?.toString();
    if (data['type'] != arrivalEvent ||
        deliveryId == null ||
        data['orderId'] == null) return;
    final local = FlutterLocalNotificationsPlugin();
    await local.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings()));
    await local.show(
        deliveryId.codeUnits
            .fold<int>(0, (hash, c) => 0x1fffffff & (hash * 31 + c)),
        '¡Llegó tu pedido!',
        'Tu repartidor ya se encuentra en el punto de entrega.',
        const NotificationDetails(
            android: AndroidNotificationDetails(
                arrivalChannel, 'Llegada del pedido',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true),
            iOS: DarwinNotificationDetails(
                presentAlert: true, presentSound: true)),
        payload: jsonEncode(data));
  }
}
