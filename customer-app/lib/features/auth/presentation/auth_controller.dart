import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../../courier/tracking/presentation/courier_tracking_controller.dart';
import '../../courier/notifications/courier_notification_service.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);
final authControllerProvider =
    AsyncNotifierProvider<AuthController, SessionUser?>(AuthController.new);

class AuthController extends AsyncNotifier<SessionUser?> {
  late final AuthRepository _repository;
  @override
  Future<SessionUser?> build() async {
    _repository = ref.read(authRepositoryProvider);
    try {
      return await _repository.restore();
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String tenant, String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.login(
        tenantCode: tenant,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> register(
    String tenant,
    String first,
    String last,
    String email,
    String password,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.register(
        tenantCode: tenant,
        firstName: first,
        lastName: last,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> logout() async {
    await ref.read(courierTrackingControllerProvider.notifier).stopTracking();
    if (state.value?.isCourier == true) {
      await CourierNotificationService.unregisterCurrent(
          ref.read(apiClientProvider));
    }
    await _repository.logout();
    state = const AsyncData(null);
  }
}
