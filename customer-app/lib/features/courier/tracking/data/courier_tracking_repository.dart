import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../domain/courier_location_update.dart';

class CourierTrackingRepository {
  CourierTrackingRepository(this.api);
  final ApiClient api;

  Future<void> sendLocation(CourierLocationUpdate location) async {
    try {
      final response = await api.dio.post<void>(
        '/api/v1/couriers/location',
        data: location.toJson(),
      );
      if (kDebugMode) {
        debugPrint('[CourierTracking] backend response=${response.statusCode}');
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final fallback = switch (status) {
        400 => 'La ubicación capturada no es válida.',
        401 => 'Tu sesión expiró.',
        403 => 'Tu cuenta no puede compartir ubicación.',
        409 => 'No existe una entrega activa compatible.',
        422 => 'La ubicación no cumple la precisión requerida.',
        429 => 'Se enviaron ubicaciones con demasiada frecuencia.',
        _ when status != null && status >= 500 =>
          'El servidor no pudo recibir la ubicación.',
        _ => 'Sin conexión; la ubicación se enviará al reconectar.',
      };
      final parsed = api.exception(error);
      throw AppException(
        parsed.code == 'NETWORK_ERROR' ? fallback : parsed.message,
        code: parsed.code,
      );
    }
  }
}
