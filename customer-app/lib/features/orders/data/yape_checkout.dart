class YapeSettings {
  const YapeSettings(
      {required this.enabled,
      this.phone,
      this.holderName,
      this.qrUrl,
      this.version});
  final bool enabled;
  final String? phone, holderName, qrUrl, version;
  factory YapeSettings.fromJson(Map<String, dynamic> json) => YapeSettings(
      enabled: json['enabled'] == true,
      phone: json['phone'] as String?,
      holderName: json['holderName'] as String?,
      qrUrl: json['qrUrl'] as String?,
      version: json['version'] as String?);
  bool get available =>
      enabled &&
      [phone, holderName, version]
          .every((v) => v != null && v.trim().isNotEmpty) &&
      qrUrl != null &&
      Uri.tryParse(qrUrl!)?.hasAuthority == true &&
      ['https', 'http'].contains(Uri.tryParse(qrUrl!)?.scheme);
}

class YapeCheckoutSnapshot {
  const YapeCheckoutSnapshot(
      {required this.merchantId,
      required this.addressId,
      required this.total,
      required this.deliveryFee,
      required this.currency});
  final String merchantId, addressId, currency;
  final double total, deliveryFee;
  bool sameAs(YapeCheckoutSnapshot other) =>
      merchantId == other.merchantId &&
      addressId == other.addressId &&
      total == other.total &&
      deliveryFee == other.deliveryFee &&
      currency == other.currency;
}

class YapeDeclaration {
  const YapeDeclaration(this.snapshot, this.version);
  final YapeCheckoutSnapshot snapshot;
  final String version;
  bool matches(YapeCheckoutSnapshot current, String? currentVersion) =>
      current.currency == 'PEN' &&
      snapshot.sameAs(current) &&
      version == currentVersion;
}
