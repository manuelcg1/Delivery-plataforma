import 'tracking_location.dart';

class CustomerTrackingEvent {
  const CustomerTrackingEvent({
    required this.type,
    required this.orderId,
    required this.deliveryStatus,
    required this.publishedAt,
    this.deliveryId,
    this.location,
  });

  final String type;
  final String orderId;
  final String? deliveryId;
  final String deliveryStatus;
  final TrackingLocation? location;
  final DateTime publishedAt;

  factory CustomerTrackingEvent.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    final published = DateTime.tryParse(json['publishedAt']?.toString() ?? '');
    if (published == null) throw const FormatException('publishedAt inválido');
    return CustomerTrackingEvent(
      type: json['type']?.toString() ?? 'UNKNOWN',
      orderId: json['orderId']?.toString() ?? '',
      deliveryId: json['deliveryId']?.toString(),
      deliveryStatus: json['deliveryStatus']?.toString() ?? 'UNKNOWN',
      location: location is Map
          ? TrackingLocation.fromJson(location.cast<String, dynamic>())
          : null,
      publishedAt: published.toUtc(),
    );
  }
}
