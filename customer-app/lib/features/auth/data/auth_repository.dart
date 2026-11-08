import '../../../core/api/api_client.dart';
import '../../../core/auth/session_store.dart';

class SessionUser {
  const SessionUser({
    required this.id,
    required this.firstName,
    required this.tenantCode,
    required this.tenantId,
    required this.roles,
    required this.permissions,
  });
  final String id, firstName, tenantCode, tenantId;
  final Set<String> roles;
  final Set<String> permissions;
  bool get isCourier =>
      roles.contains('COURIER') ||
      permissions.contains('COURIER_AVAILABILITY_MANAGE');
  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: j['id'] as String,
        firstName: j['firstName'] as String,
        tenantCode: (j['tenant'] as Map<String, dynamic>)['code'] as String,
        tenantId: (j['tenant'] as Map<String, dynamic>)['id'] as String,
        roles: ((j['roles'] as List<dynamic>?) ?? const [])
            .map((role) => role.toString())
            .toSet(),
        permissions: ((j['permissions'] as List<dynamic>?) ?? const [])
            .map((permission) => permission.toString())
            .toSet(),
      );
}

class MobileRegistrationResult {
  const MobileRegistrationResult({this.user, this.message});
  final SessionUser? user;
  final String? message;
  bool get pendingApproval => user == null;
}

class AuthRepository {
  AuthRepository(this.api, this.store);
  final ApiClient api;
  final SessionStore store;
  Future<SessionUser> login({
    String tenantCode = '',
    required String email,
    required String password,
  }) =>
      _session('/api/v1/auth/login-mobile', {
        'email': email,
        'password': password,
      });
  Future<MobileRegistrationResult> register({
    String tenantCode = '',
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    String profile = 'CUSTOMER',
  }) async {
    try {
      final response = await api.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register-mobile',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
          'phone': phone,
          'profile': profile,
        },
      );
      final json = response.data!;
      if (json['pendingApproval'] == true) {
        return MobileRegistrationResult(
          message: json['message'] as String? ??
              'Tu cuenta de repartidor está pendiente de activación por el administrador.',
        );
      }
      return MobileRegistrationResult(user: await _save(json));
    } catch (error) {
      throw api.exception(error);
    }
  }

  Future<SessionUser> restore() async {
    await api.ensureValidSession();
    final response = await api.dio.get<Map<String, dynamic>>('/api/v1/auth/me');
    return SessionUser.fromJson(response.data!);
  }

  Future<void> logout() async {
    try {
      final refreshToken = await store.refreshToken();
      await api.dio.post<void>('/api/v1/auth/logout-mobile',
          data: {'refreshToken': refreshToken});
    } finally {
      await store.clear();
    }
  }

  Future<SessionUser> _session(String path, Map<String, dynamic> data) async {
    try {
      final response =
          await api.dio.post<Map<String, dynamic>>(path, data: data);
      return _save(response.data!);
    } catch (error) {
      // Dio keeps the user-facing AppException inside DioException.error.
      // Unwrap it here so the presentation layer can display the real cause.
      throw api.exception(error);
    }
  }

  Future<SessionUser> _save(Map<String, dynamic> json) async {
    await store.save(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
    );
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }
}
