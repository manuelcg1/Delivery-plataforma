import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'yape_checkout.dart';

class YapeRecoveryIntent {
  const YapeRecoveryIntent(
      {required this.snapshot,
      required this.version,
      required this.checkoutKey,
      required this.paymentKey,
      this.orderId});
  final YapeCheckoutSnapshot snapshot;
  final String version, checkoutKey, paymentKey;
  final String? orderId;
  YapeRecoveryIntent withOrder(String id) => YapeRecoveryIntent(
      snapshot: snapshot,
      version: version,
      checkoutKey: checkoutKey,
      paymentKey: paymentKey,
      orderId: id);
  Map<String, dynamic> toJson() => {
        'merchant': snapshot.merchantId,
        'address': snapshot.addressId,
        'total': snapshot.total,
        'fee': snapshot.deliveryFee,
        'currency': snapshot.currency,
        'version': version,
        'checkoutKey': checkoutKey,
        'paymentKey': paymentKey,
        'orderId': orderId
      };
  factory YapeRecoveryIntent.fromJson(
          Map<String, dynamic> j) =>
      YapeRecoveryIntent(
          snapshot: YapeCheckoutSnapshot(
              merchantId: j['merchant'] as String,
              addressId: j['address'] as String,
              total: (j['total'] as num).toDouble(),
              deliveryFee: (j['fee'] as num).toDouble(),
              currency: j['currency'] as String),
          version: j['version'] as String,
          checkoutKey: j['checkoutKey'] as String,
          paymentKey: j['paymentKey'] as String,
          orderId: j['orderId'] as String?);
}

class YapeRecoveryStore {
  YapeRecoveryStore(String tenant, String user, {String origin = ''})
      : key =
            'yape-recovery:v1:${base64Url.encode(utf8.encode('$origin|$tenant|$user'))}';
  final String key;
  Future<void> save(YapeRecoveryIntent intent) async {
    final p = await SharedPreferences.getInstance();
    if (!await p.setString(key, jsonEncode(intent.toJson())))
      throw StateError('No se pudo guardar la declaración pendiente.');
  }

  Future<YapeRecoveryIntent?> read() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    return raw == null
        ? null
        : YapeRecoveryIntent.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>());
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    if (!await p.remove(key))
      throw StateError('No se pudo actualizar la declaración pendiente.');
  }
}

class YapeRecoveryService {
  YapeRecoveryService(this.store);
  final YapeRecoveryStore store;
  Future<void> resume(
      {required Future<String> Function(YapeRecoveryIntent) createOrder,
      required Future<void> Function(YapeRecoveryIntent) declare}) async {
    final intent = await store.read();
    if (intent == null) return;
    // Checkout currently has no server-side idempotency. Never replay an uncertain create.
    if (intent.orderId == null)
      throw StateError(
          'Revisa tus pedidos y contacta al comercio. No repitas el Yape ni crees otro pedido para esta transferencia.');
    await declare(intent);
    await store.clear();
  }
}
