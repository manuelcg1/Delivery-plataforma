import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../auth/session_store.dart';
import '../errors/app_exception.dart';

class ApiClient {
  ApiClient(String baseUrl, this.store)
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _request, onError: _error),
    );
  }
  final Dio dio;
  final SessionStore store;
  bool _refreshing = false;
  Future<void> _request(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await store.accessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    options.headers['X-Correlation-Id'] = const Uuid().v4();
    handler.next(options);
  }

  Future<void> _error(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401 &&
        !_refreshing &&
        !error.requestOptions.path.contains('/auth/refresh')) {
      _refreshing = true;
      try {
        final refresh = await store.refreshToken();
        if (refresh != null) {
          final response = await Dio(BaseOptions(baseUrl: dio.options.baseUrl))
              .post<Map<String, dynamic>>(
            '/api/v1/auth/refresh-mobile',
            data: {'refreshToken': refresh},
          );
          final token = response.data?['accessToken'] as String?;
          if (token != null) {
            await store.save(accessToken: token);
            final request = error.requestOptions;
            request.headers['Authorization'] = 'Bearer $token';
            handler.resolve(await dio.fetch<dynamic>(request));
            return;
          }
        }
      } catch (_) {
        await store.clear();
      } finally {
        _refreshing = false;
      }
    }
    final data = error.response?.data;
    final map = data is Map<String, dynamic> ? data : null;
    final details = (map?['details'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ) ??
        <String, String>{};
    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: AppException(
          map?['message']?.toString() ?? _friendly(error),
          code: map?['code']?.toString() ?? 'NETWORK_ERROR',
          fieldErrors: details,
        ),
      ),
    );
  }

  String _friendly(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout
          ? 'La conexión tardó demasiado. Intenta nuevamente.'
          : 'No pudimos conectarnos. Revisa tu conexión.';
  AppException exception(Object error) {
    if (error is DioException && error.error is AppException)
      return error.error! as AppException;
    return const AppException('No se pudo completar la operación.');
  }
}
