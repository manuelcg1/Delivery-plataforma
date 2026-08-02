import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/courier/notifications/courier_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(courierFirebaseBackgroundHandler);
  runApp(const ProviderScope(child: CustomerApp()));
}
