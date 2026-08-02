class CustomerAddress {
  const CustomerAddress(
      {required this.id,
      required this.label,
      required this.formattedAddress,
      required this.latitude,
      required this.longitude,
      required this.countryCode,
      required this.isDefault,
      this.recipientName = '',
      this.phone = '',
      this.placeId,
      this.street,
      this.streetNumber,
      this.district,
      this.city,
      this.province,
      this.region,
      this.postalCode,
      this.apartment,
      this.reference,
      this.deliveryInstructions,
      this.locationSource = 'MAP'});
  final String id,
      label,
      formattedAddress,
      countryCode,
      recipientName,
      phone,
      locationSource;
  final String? placeId,
      street,
      streetNumber,
      district,
      city,
      province,
      region,
      postalCode,
      apartment,
      reference,
      deliveryInstructions;
  final double latitude, longitude;
  final bool isDefault;
  String get addressLine => formattedAddress;

  factory CustomerAddress.fromJson(Map<String, dynamic> j) => CustomerAddress(
      id: j['id'] as String,
      label: j['label'] as String,
      formattedAddress: (j['formattedAddress'] ?? j['addressLine']) as String,
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
      countryCode: (j['countryCode'] ?? 'PE') as String,
      isDefault: j['isDefault'] as bool? ?? false,
      recipientName: j['recipientName']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      placeId: j['placeId'] as String?,
      street: j['street'] as String?,
      streetNumber: j['streetNumber'] as String?,
      district: j['district'] as String?,
      city: j['city'] as String?,
      province: j['province'] as String?,
      region: j['region'] as String?,
      postalCode: j['postalCode'] as String?,
      apartment: j['apartment'] as String?,
      reference: j['reference'] as String?,
      deliveryInstructions: j['deliveryInstructions'] as String?,
      locationSource: j['locationSource']?.toString() ?? 'LEGACY');

  Map<String, dynamic> toRequest() => {
        'label': label,
        'recipientName': recipientName,
        'phone': phone,
        'formattedAddress': formattedAddress,
        'placeId': placeId,
        'latitude': latitude,
        'longitude': longitude,
        'street': street,
        'streetNumber': streetNumber,
        'district': district,
        'city': city,
        'province': province,
        'region': region,
        'postalCode': postalCode,
        'countryCode': countryCode,
        'apartment': apartment,
        'reference': reference,
        'deliveryInstructions': deliveryInstructions,
        'locationSource': locationSource,
        'isDefault': isDefault
      };
}

bool validCoordinates(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
