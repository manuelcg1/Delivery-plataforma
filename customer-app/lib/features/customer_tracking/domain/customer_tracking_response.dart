import 'tracking_courier.dart';
import 'tracking_location.dart';

class CustomerOrderTracking {
  const CustomerOrderTracking({
    required this.orderId,
    required this.deliveryStatus,
    required this.trackingActive,
    required this.stale,
    this.deliveryId,
    this.courier,
    this.location,
    this.updatedAt,
  });

  final String orderId;
  final String? deliveryId;
  final String deliveryStatus;
  final TrackingCourier? courier;
  final TrackingLocation? location;
  final DateTime? updatedAt;
  final bool trackingActive;
  final bool stale;

  factory CustomerOrderTracking.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    final courier = json['courier'];
    return CustomerOrderTracking(
      orderId: json['orderId']?.toString() ?? '',
      deliveryId: json['deliveryId']?.toString(),
      deliveryStatus: json['deliveryStatus']?.toString() ?? 'UNKNOWN',
      courier: courier is Map
          ? TrackingCourier.fromJson(courier.cast<String, dynamic>())
          : null,
      location: location is Map
          ? TrackingLocation.fromJson(location.cast<String, dynamic>())
          : null,
      updatedAt: _date(json['updatedAt']),
      trackingActive: json['trackingActive'] == true,
      stale: json['stale'] != false,
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  CustomerOrderTracking apply({
    required String status,
    TrackingLocation? nextLocation,
    required bool active,
    required DateTime publishedAt,
  }) =>
      CustomerOrderTracking(
        orderId: orderId,
        deliveryId: deliveryId,
        deliveryStatus: status,
        courier: courier,
        location: nextLocation ?? location,
        updatedAt: publishedAt,
        trackingActive: active,
        stale: nextLocation == null ? stale : false,
      );
}
