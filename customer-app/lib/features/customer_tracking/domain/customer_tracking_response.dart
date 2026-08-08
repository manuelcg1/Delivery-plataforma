import 'tracking_courier.dart';
import 'tracking_location.dart';
export '../../../core/maps/encoded_polyline.dart' show decodePolyline;

class CustomerOrderTracking {
  const CustomerOrderTracking({
    required this.orderId,
    required this.deliveryStatus,
    required this.trackingActive,
    required this.stale,
    this.deliveryId,
    this.courier,
    this.location,
    this.route,
    this.updatedAt,
  });

  final String orderId;
  final String? deliveryId;
  final String deliveryStatus;
  final TrackingCourier? courier;
  final TrackingLocation? location;
  final TrackingRoute? route;
  final DateTime? updatedAt;
  final bool trackingActive;
  final bool stale;

  factory CustomerOrderTracking.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    final courier = json['courier'];
    final route = json['route'];
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
      route: route is Map
          ? TrackingRoute.fromJson(route.cast<String, dynamic>())
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
        route: route,
        updatedAt: publishedAt,
        trackingActive: active,
        stale: nextLocation == null ? stale : false,
      );

  CustomerOrderTracking withLocation(TrackingLocation? newestLocation) =>
      CustomerOrderTracking(
        orderId: orderId,
        deliveryId: deliveryId,
        deliveryStatus: deliveryStatus,
        courier: courier,
        location: newestLocation,
        route: route,
        updatedAt: updatedAt,
        trackingActive: trackingActive,
        stale: stale,
      );
}

class TrackingRoute {
  const TrackingRoute({
    required this.polyline,
    required this.provider,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.generatedAt,
  });

  final String polyline;
  final String provider;
  final DateTime? generatedAt;
  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  factory TrackingRoute.fromJson(Map<String, dynamic> json) => TrackingRoute(
        polyline: json['polyline']?.toString() ?? '',
        provider: json['provider']?.toString() ?? '',
        generatedAt: CustomerOrderTracking._date(json['generatedAt']),
        originLatitude: (json['originLatitude'] as num).toDouble(),
        originLongitude: (json['originLongitude'] as num).toDouble(),
        destinationLatitude: (json['destinationLatitude'] as num).toDouble(),
        destinationLongitude: (json['destinationLongitude'] as num).toDouble(),
      );
}
