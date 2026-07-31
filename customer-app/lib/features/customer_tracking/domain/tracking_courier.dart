class TrackingCourier {
  const TrackingCourier({required this.courierId, required this.displayName});
  final String courierId;
  final String displayName;

  factory TrackingCourier.fromJson(Map<String, dynamic> json) =>
      TrackingCourier(
        courierId: json['courierId']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? 'Repartidor',
      );
}
