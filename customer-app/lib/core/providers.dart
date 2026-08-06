import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api/api_client.dart';
import 'auth/session_store.dart';
import 'config/app_config.dart';
import 'realtime/realtime_client.dart';

final configProvider = Provider((_) => AppConfig.fromEnvironment());
final sessionStoreProvider = Provider(
  (_) => const SessionStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  ),
);
final apiClientProvider = Provider(
  (ref) => ApiClient(
    ref.watch(configProvider).apiBaseUrl,
    ref.watch(sessionStoreProvider),
  ),
);
final realtimeClientProvider = Provider((ref) {
  final client = RealtimeClient(
      ref.watch(configProvider).realtimeUrl, ref.watch(sessionStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});
final customerRealtimeClientProvider = Provider((ref) {
  final client = RealtimeClient(
      ref.watch(configProvider).realtimeUrl, ref.watch(sessionStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});

final customerMainTabProvider = StateProvider<int>((_) => 0);
final appRecoveryRevisionProvider = StateProvider<int>((_) => 0);
