class TrackingLocation {
  const TrackingLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.gpsTimestamp,
    this.speed,
    this.heading,
    this.altitude,
  });

  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final double accuracy;
  final double? altitude;
  final DateTime gpsTimestamp;

  factory TrackingLocation.fromJson(Map<String, dynamic> json) =>
      TrackingLocation(
        latitude: _number(json, 'latitude'),
        longitude: _number(json, 'longitude'),
        speed: _optionalNumber(json['speed']),
        heading: _optionalNumber(json['heading']),
        accuracy: _number(json, 'accuracy'),
        altitude: _optionalNumber(json['altitude']),
        gpsTimestamp:
            DateTime.parse(_requiredString(json, 'gpsTimestamp')).toUtc(),
      );

  static double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) throw FormatException('$key debe ser numérico');
    return value.toDouble();
  }

  static double? _optionalNumber(Object? value) =>
      value is num ? value.toDouble() : null;

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty)
      throw FormatException('$key es obligatorio');
    return value;
  }
}
