class CourierLocationUpdate {
  const CourierLocationUpdate({
    required this.deliveryId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.provider,
    required this.gpsTimestamp,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
  });

  final String deliveryId;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final double accuracy;
  final double? altitude;
  final String provider;
  final int? batteryLevel;
  final DateTime gpsTimestamp;

  bool get isValid =>
      latitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude.isFinite &&
      longitude >= -180 &&
      longitude <= 180 &&
      accuracy.isFinite &&
      accuracy > 0 &&
      gpsTimestamp.millisecondsSinceEpoch > 0;

  Map<String, dynamic> toJson() => {
        'deliveryId': deliveryId,
        'latitude': latitude,
        'longitude': longitude,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        'accuracy': accuracy,
        if (altitude != null) 'altitude': altitude,
        'provider': provider,
        if (batteryLevel != null) 'batteryLevel': batteryLevel,
        'gpsTimestamp': gpsTimestamp.toUtc().toIso8601String(),
      };
}
