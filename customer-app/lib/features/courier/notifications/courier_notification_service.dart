import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/config/app_config.dart';
import '../../../core/realtime/realtime_client.dart';
import '../data/courier_repository.dart';

const assignmentEvent = 'NEW_DELIVERY_ASSIGNMENT';
const assignmentChannel = 'CERKA_NEW_DELIVERY';

@pragma('vm:entry-point')
Future<void> courierFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await CourierNotificationService.showBackground(message.data);
}

@pragma('vm:entry-point')
Future<void> courierNotificationActionBackground(
    NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final payload = response.payload == null
      ? null
      : jsonDecode(response.payload!) as Map<String, dynamic>;
  final id = payload?['deliveryId']?.toString();
  if (id == null || !const {'ACCEPT', 'REJECT'}.contains(response.actionId))
    return;
  const store = SessionStore(FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true)));
  final api = ApiClient(AppConfig.fromEnvironment().apiBaseUrl, store);
  await CourierRepository(api).updateDelivery(
      id, response.actionId == 'ACCEPT' ? 'ACCEPTED' : 'REJECTED');
  await CourierNotificationService.cancelLocal(id);
}

class CourierNotificationService {
  CourierNotificationService(this.api, this.repository, {this.onOpenDelivery});
  final ApiClient api;
  final CourierRepository repository;
  final Future<void> Function(String deliveryId)? onOpenDelivery;
  final local = FlutterLocalNotificationsPlugin();
  final handled = <String>{};
  StreamSubscription<RemoteMessage>? messages;
  StreamSubscription<String>? tokenChanges;

  static const channel = AndroidNotificationChannel(
    assignmentChannel,
    'Nuevos pedidos',
    description: 'Ofertas urgentes de entrega',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  Future<void> initialize() async {
    await local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _action,
      onDidReceiveBackgroundNotificationResponse:
          courierNotificationActionBackground,
    );
    await local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final launch = await local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse != null) {
      await _action(launch!.notificationResponse!);
    }
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, provisional: false);
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
      tokenChanges =
          FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      messages = FirebaseMessaging.onMessage.listen((m) => receive(m.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await receive(initial.data);
    } catch (_) {
      // Builds without Firebase app files remain usable through WebSocket.
    }
    await reconcile();
  }

  Future<void> receiveRealtime(RealtimeEvent event) async {
    if (event.type == assignmentEvent ||
        event.type == 'COURIER_ASSIGNMENT_PENDING' ||
        event.type == 'CourierAssigned') {
      await receive({...event.payload, 'type': assignmentEvent});
    } else if (event.type == 'DELIVERY_ASSIGNMENT_CLOSED') {
      await cancel(event.payload['deliveryId']?.toString());
    }
  }

  Future<void> receive(Map<String, dynamic> data) async {
    final deliveryId = data['deliveryId']?.toString();
    if (deliveryId == null || data['type'] != assignmentEvent) return;
    final eventId =
        data['eventId']?.toString() ?? '$assignmentEvent:$deliveryId';
    if (!handled.add(eventId)) return;
    await _show(data);
  }

  Future<void> reconcile() async {
    try {
      for (final delivery in await repository.deliveries()) {
        if (delivery.status == 'ASSIGNED')
          await receive({
            'type': assignmentEvent,
            'deliveryId': delivery.id,
            'orderId': delivery.orderId,
            'merchantName': 'Nuevo comercio',
            'customerName': 'Cliente',
            'estimatedDistanceKm': '--',
            'estimatedTimeMinutes': '--',
            'total': '',
            'eventId': 'reconcile:${delivery.id}',
          });
      }
    } catch (_) {}
  }

  Future<void> cancel(String? deliveryId) async {
    if (deliveryId != null) await local.cancel(notificationId(deliveryId));
  }

  Future<void> _show(Map<String, dynamic> data) async {
    final id = data['deliveryId'].toString();
    final merchant = data['merchantName']?.toString() ?? 'Comercio';
    final body =
        '${data['customerName'] ?? 'Cliente'} · ${data['estimatedDistanceKm'] ?? '--'} km · ${data['total'] ?? ''}\nTiempo estimado ${data['estimatedTimeMinutes'] ?? '--'} min';
    await local.show(
        notificationId(id),
        '🛵 Nuevo pedido · $merchant',
        body,
        NotificationDetails(
            android: AndroidNotificationDetails(
              assignmentChannel,
              'Nuevos pedidos',
              channelDescription: 'Ofertas urgentes de entrega',
              importance: Importance.max,
              priority: Priority.high,
              category: AndroidNotificationCategory.call,
              visibility: NotificationVisibility.public,
              ongoing: true,
              autoCancel: false,
              fullScreenIntent: false,
              enableVibration: true,
              vibrationPattern: Int64List.fromList([0, 700, 350, 700]),
              color: const Color(0xFF2563EB),
              styleInformation: BigTextStyleInformation(body),
              actions: const [
                AndroidNotificationAction('ACCEPT', 'ACEPTAR',
                    showsUserInterface: false, cancelNotification: false),
                AndroidNotificationAction('REJECT', 'RECHAZAR',
                    showsUserInterface: false, cancelNotification: false)
              ],
            ),
            iOS: const DarwinNotificationDetails(
                presentAlert: true, presentBadge: true, presentSound: true)),
        payload: jsonEncode({'deliveryId': id}));
  }

  Future<void> _action(NotificationResponse response) async {
    final payload = response.payload == null
        ? null
        : jsonDecode(response.payload!) as Map<String, dynamic>;
    final id = payload?['deliveryId']?.toString();
    if (id == null) return;
    if (response.actionId == 'ACCEPT' || response.actionId == 'REJECT') {
      await repository.updateDelivery(
          id, response.actionId == 'ACCEPT' ? 'ACCEPTED' : 'REJECTED');
      await cancel(id);
    } else {
      await onOpenDelivery?.call(id);
    }
  }

  Future<void> _register(String token) => api.dio.post<void>(
      '/api/v1/couriers/me/device-tokens',
      data: {'token': token, 'platform': Platform.isIOS ? 'IOS' : 'ANDROID'});
  static Future<void> unregisterCurrent(ApiClient api) async {
    try {
      await Firebase.initializeApp();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await api.dio.delete<void>('/api/v1/couriers/me/device-tokens', data: {
          'token': token,
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
        });
      }
    } catch (error) {
      debugPrint('No se pudo desactivar el token FCM al cerrar sesión: $error');
    }
  }

  Future<void> dispose() async {
    await messages?.cancel();
    await tokenChanges?.cancel();
  }

  static int notificationId(String value) =>
      value.codeUnits.fold(0, (hash, c) => 0x1fffffff & (hash * 31 + c));
  static Future<void> cancelLocal(String deliveryId) =>
      FlutterLocalNotificationsPlugin().cancel(notificationId(deliveryId));
  static Future<void> showBackground(Map<String, dynamic> data) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings()));
    final deliveryId = data['deliveryId']?.toString();
    if (deliveryId == null || data['type'] != assignmentEvent) return;
    final merchant = data['merchantName']?.toString() ?? 'Comercio';
    final body =
        '${data['customerName'] ?? 'Cliente'} · ${data['estimatedDistanceKm'] ?? '--'} km · ${data['total'] ?? ''}\nTiempo estimado ${data['estimatedTimeMinutes'] ?? '--'} min';
    await plugin.show(
        notificationId(deliveryId),
        '🛵 Nuevo pedido · $merchant',
        body,
        NotificationDetails(
            android: AndroidNotificationDetails(
                assignmentChannel, 'Nuevos pedidos',
                channelDescription: 'Ofertas urgentes de entrega',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.call,
                visibility: NotificationVisibility.public,
                ongoing: true,
                autoCancel: false,
                enableVibration: true,
                vibrationPattern: Int64List.fromList([0, 700, 350, 700]),
                color: const Color(0xFF2563EB),
                actions: const [
              AndroidNotificationAction('ACCEPT', 'ACEPTAR',
                  showsUserInterface: false),
              AndroidNotificationAction('REJECT', 'RECHAZAR',
                  showsUserInterface: false)
            ])),
        payload: jsonEncode({'deliveryId': deliveryId}));
  }
}
