import '../../home/presentation/home_page.dart';
import '../../orders/presentation/commerce_pages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../../courier/tracking/presentation/courier_tracking_controller.dart';
import '../../../core/notifications/push_notification_service.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);
final authControllerProvider =
    AsyncNotifierProvider<AuthController, SessionUser?>(AuthController.new);

class AuthController extends AsyncNotifier<SessionUser?> {
  void _invalidateAccountData() {
    ref.invalidate(cartProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(addressesProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(merchantsProvider);
  }

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
    _invalidateAccountData();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.login(
        tenantCode: tenant,
        email: email,
        password: password,
      ),
    );
    _invalidateAccountData();
  }

  Future<MobileRegistrationResult?> register(
    String tenant,
    String first,
    String last,
    String email,
    String password, {
    required String phone,
    String profile = 'CUSTOMER',
  }) async {
    _invalidateAccountData();
    state = const AsyncLoading();
    try {
      final result = await _repository.register(
        firstName: first,
        lastName: last,
        email: email,
        password: password,
        phone: phone,
        profile: profile,
      );
      state = AsyncData(result.user);
      _invalidateAccountData();
      return result;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return null;
    }
  }

  Future<void> logout() async {
    await ref.read(courierTrackingControllerProvider.notifier).stopTracking();
    await PushNotificationService.unregisterCurrent(
        ref.read(apiClientProvider));
    await _repository.logout();
    _invalidateAccountData();
    state = const AsyncData(null);
  }
}
