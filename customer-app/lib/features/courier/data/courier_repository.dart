import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class CourierProfile {
  const CourierProfile({
    required this.id,
    required this.name,
    required this.vehicleType,
    required this.status,
    required this.activeDeliveries,
    required this.maxActiveDeliveries,
  });

  final String id, name, vehicleType, status;
  final int activeDeliveries, maxActiveDeliveries;

  factory CourierProfile.fromJson(Map<String, dynamic> json) => CourierProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        vehicleType: json['vehicleType'] as String,
        status: json['status'] as String,
        activeDeliveries: json['activeDeliveries'] as int,
        maxActiveDeliveries: json['maxActiveDeliveries'] as int,
      );
}

class CourierDelivery {
  const CourierDelivery({
    required this.id,
    required this.orderId,
    required this.status,
    required this.deliveryType,
    required this.pickupNotes,
    required this.deliveryNotes,
    required this.createdAt,
  });

  final String id, orderId, status, deliveryType, createdAt;
  final String? pickupNotes, deliveryNotes;

  factory CourierDelivery.fromJson(Map<String, dynamic> json) =>
      CourierDelivery(
        id: json['id'] as String,
        orderId: json['orderId'] as String,
        status: json['status'] as String,
        deliveryType: json['deliveryType'] as String,
        pickupNotes: json['pickupNotes'] as String?,
        deliveryNotes: json['deliveryNotes'] as String?,
        createdAt: json['createdAt'] as String,
      );
}

class CourierDeliveryRoute {
  const CourierDeliveryRoute({
    required this.deliveryId,
    required this.orderId,
    required this.deliveryStatus,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.destinationAddress,
    required this.destinationReference,
    required this.deliveryNotes,
    required this.merchantName,
    required this.merchantAddress,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.routePolyline,
    required this.routeProvider,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final String deliveryId, orderId, deliveryStatus, orderNumber;
  final String? customerName, customerPhone, destinationAddress;
  final String? destinationReference, deliveryNotes, merchantName, merchantAddress;
  final double? originLatitude, originLongitude;
  final double? destinationLatitude, destinationLongitude;
  final String? routePolyline, routeProvider;
  final double? distanceKm;
  final int? etaMinutes;

  bool get hasDestination =>
      destinationLatitude != null && destinationLongitude != null;
  bool get hasOrigin => originLatitude != null && originLongitude != null;

  factory CourierDeliveryRoute.fromJson(Map<String, dynamic> json) =>
      CourierDeliveryRoute(
        deliveryId: json['deliveryId']?.toString() ?? '',
        orderId: json['orderId']?.toString() ?? '',
        deliveryStatus: json['deliveryStatus']?.toString() ?? 'UNKNOWN',
        orderNumber: json['orderNumber']?.toString() ?? '',
        customerName: json['customerName']?.toString(),
        customerPhone: json['customerPhone']?.toString(),
        destinationAddress: json['destinationAddress']?.toString(),
        destinationReference: json['destinationReference']?.toString(),
        deliveryNotes: json['deliveryNotes']?.toString(),
        merchantName: json['merchantName']?.toString(),
        merchantAddress: json['merchantAddress']?.toString(),
        originLatitude: (json['originLatitude'] as num?)?.toDouble(),
        originLongitude: (json['originLongitude'] as num?)?.toDouble(),
        destinationLatitude: (json['destinationLatitude'] as num?)?.toDouble(),
        destinationLongitude: (json['destinationLongitude'] as num?)?.toDouble(),
        routePolyline: json['routePolyline']?.toString(),
        routeProvider: json['routeProvider']?.toString(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      );
}

class CourierNotification {
  const CourierNotification({
    required this.id,
    required this.deliveryId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.deliveryStatus,
  });

  final String id, deliveryId, title, body, createdAt;
  final String? deliveryStatus;

  factory CourierNotification.fromJson(Map<String, dynamic> json) =>
      CourierNotification(
        id: json['id'] as String,
        deliveryId: json['deliveryId'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: json['createdAt'] as String,
        deliveryStatus: json['deliveryStatus'] as String?,
      );
}

const courierNoticeTerminalStatuses = <String>{
  'DELIVERED',
  'CANCELLED',
  'FAILED',
  'REJECTED',
  'EXPIRED',
};

bool isCourierNoticeActive(String? deliveryStatus) =>
    deliveryStatus == null ||
    !courierNoticeTerminalStatuses.contains(deliveryStatus);

bool shouldShowCourierNotice(CourierNotification notice) =>
    isCourierNoticeActive(notice.deliveryStatus);

class CourierDeliveryHistory {
  const CourierDeliveryHistory({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final String id, status, createdAt;

  factory CourierDeliveryHistory.fromJson(Map<String, dynamic> json) =>
      CourierDeliveryHistory(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
      );
}

class CourierRepository {
  CourierRepository(this.api);
  final ApiClient api;

  Future<CourierProfile> profile() async {
    final response =
        await api.dio.get<Map<String, dynamic>>('/api/v1/couriers/me');
    return CourierProfile.fromJson(response.data!);
  }

  Future<CourierProfile> updateAvailability(String status) async {
    final response = await api.dio.put<Map<String, dynamic>>(
      '/api/v1/couriers/status',
      data: {'status': status},
    );
    return CourierProfile.fromJson(response.data!);
  }

  Future<List<CourierDelivery>> deliveries() async {
    final response = await api.dio.get<Map<String, dynamic>>(
      '/api/v1/deliveries',
      queryParameters: {'size': 100},
    );
    return (response.data!['content'] as List<dynamic>)
        .map((item) => CourierDelivery.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CourierDelivery> delivery(String id) async {
    final response =
        await api.dio.get<Map<String, dynamic>>('/api/v1/deliveries/$id');
    return CourierDelivery.fromJson(response.data!);
  }

  Future<CourierDeliveryRoute> route(String deliveryId) async {
    final response = await api.dio.get<Map<String, dynamic>>(
      '/api/v1/courier/deliveries/$deliveryId/route',
    );
    return CourierDeliveryRoute.fromJson(response.data!);
  }

  Future<CourierDelivery> updateDelivery(String id, String status) async {
    final response = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/deliveries/$id/status',
      data: {'status': status, 'notes': 'Actualizado por el repartidor'},
      options: Options(headers: {'Idempotency-Key': id}),
    );
    return CourierDelivery.fromJson(response.data!);
  }

  Future<bool> markArrived(String orderId) async {
    final response=await api.dio.post<Map<String,dynamic>>('/api/v1/orders/$orderId/arrival');
    return response.data?['notified']==true;
  }

  Future<List<CourierDeliveryHistory>> history(String id) async {
    final response =
        await api.dio.get<List<dynamic>>('/api/v1/deliveries/$id/history');
    return response.data!
        .map((item) =>
            CourierDeliveryHistory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CourierNotification>> notifications() async {
    final response = await api.dio.get<List<dynamic>>('/api/v1/notifications');
    final notifications = response.data!
        .map((item) =>
            CourierNotification.fromJson(item as Map<String, dynamic>))
        .where(shouldShowCourierNotice)
        .toList();
    final assigned =
        (await deliveries()).where((delivery) => delivery.status == 'ASSIGNED');
    for (final delivery in assigned) {
      if (notifications.any((item) => item.deliveryId == delivery.id)) continue;
      notifications.add(CourierNotification(
        id: 'assignment-${delivery.id}',
        deliveryId: delivery.id,
        title: 'Nueva entrega asignada',
        body: 'Tienes una nueva entrega pendiente de aceptación',
        createdAt: delivery.createdAt,
        deliveryStatus: delivery.status,
      ));
    }
    return notifications;
  }
}
