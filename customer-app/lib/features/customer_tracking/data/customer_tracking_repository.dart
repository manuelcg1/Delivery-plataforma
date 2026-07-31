import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/realtime/realtime_client.dart';
import '../domain/customer_tracking_event.dart';
import '../domain/customer_tracking_response.dart';

abstract interface class CustomerTrackingRepositoryContract {
  Future<CustomerOrderTracking> getTracking(String orderId);
  Future<CustomerTrackingSubscription> subscribeToTracking(String orderId);
  String errorMessage(Object error);
}

class CustomerTrackingSubscription {
  const CustomerTrackingSubscription({
    required this.events,
    required this.connectionStates,
    required this.cancel,
  });
  final Stream<CustomerTrackingEvent> events;
  final Stream<RealtimeConnectionState> connectionStates;
  final Future<void> Function() cancel;
}

class CustomerTrackingRepository implements CustomerTrackingRepositoryContract {
  CustomerTrackingRepository(this.api, this.realtime);
  final ApiClient api;
  final RealtimeClient realtime;

  @override
  Future<CustomerOrderTracking> getTracking(String orderId) async {
    try {
      final response = await api.dio.get<Map<String, dynamic>>(
        '/api/v1/customer/orders/$orderId/tracking',
      );
      return CustomerOrderTracking.fromJson(response.data!);
    } on DioException catch (error) {
      switch (error.response?.statusCode) {
        case 400:
          throw const AppException('El pedido no es válido.',
              code: 'ORDER_INVALID');
        case 401:
          throw const AppException(
              'Tu sesión expiró. Inicia sesión nuevamente.',
              code: 'SESSION_EXPIRED');
        case 403:
          throw const AppException(
              'No tienes permiso para consultar este pedido.',
              code: 'ACCESS_DENIED');
        case 404:
          throw const AppException('No se encontró información de seguimiento.',
              code: 'TRACKING_NOT_FOUND');
        default:
          rethrow;
      }
    }
  }

  @override
  Future<CustomerTrackingSubscription> subscribeToTracking(
      String orderId) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(orderId)) {
      throw ArgumentError.value(orderId, 'orderId', 'Pedido inválido');
    }
    final subscription = await realtime.subscribe(
      '/user/queue/orders/$orderId/tracking',
    );
    return CustomerTrackingSubscription(
      events: subscription.events.map(CustomerTrackingEvent.fromJson),
      connectionStates: subscription.connectionStates,
      cancel: subscription.cancel,
    );
  }

  @override
  String errorMessage(Object error) => api.exception(error).message;
}
