import 'package:delivery_customer/features/orders/data/yape_checkout.dart';
import 'package:delivery_customer/features/orders/data/yape_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const snapshot = YapeCheckoutSnapshot(
      merchantId: 'm',
      addressId: 'a',
      total: 25,
      deliveryFee: 5,
      currency: 'PEN');
  test('intent survives restart and is isolated by tenant and user', () async {
    final store = YapeRecoveryStore('tenant', 'user');
    final intent = YapeRecoveryIntent(
        snapshot: snapshot,
        version: 'v1',
        checkoutKey: 'checkout-key',
        paymentKey: 'payment-key');
    await store.save(intent);
    final restored = await YapeRecoveryStore('tenant', 'user').read();
    expect(restored!.snapshot.sameAs(snapshot), isTrue);
    expect(restored.paymentKey, 'payment-key');
    expect(await YapeRecoveryStore('other', 'user').read(), isNull);
    expect(await YapeRecoveryStore('tenant', 'other').read(), isNull);
    await store.save(restored.withOrder('order'));
    expect((await store.read())!.orderId, 'order');
    await store.clear();
    expect(await store.read(), isNull);
  });
  test('retry keeps the order and declaration key after a failed response',
      () async {
    final store = YapeRecoveryStore('tenant', 'user');
    await store.save(const YapeRecoveryIntent(
        snapshot: snapshot,
        version: 'v1',
        checkoutKey: 'checkout-key',
        paymentKey: 'payment-key',
        orderId: 'order'));
    final service = YapeRecoveryService(store);
    var creates = 0;
    final keys = <String>[];
    Future<void> attempt(bool fail) =>
        service.resume(createOrder: (intent) async {
          creates++;
          return 'new-order';
        }, declare: (intent) async {
          expect(intent.orderId, 'order');
          keys.add(intent.paymentKey);
          if (fail) throw StateError('response lost');
        });
    await expectLater(attempt(true), throwsStateError);
    expect(await store.read(), isNotNull);
    await attempt(false);
    expect(creates, 0);
    expect(keys, ['payment-key', 'payment-key']);
    expect(await store.read(), isNull);
  });
  test('uncertain checkout is never replayed and remains scoped to API origin',
      () async {
    final store =
        YapeRecoveryStore('tenant', 'user', origin: 'https://api.cerka.site');
    await store.save(const YapeRecoveryIntent(
        snapshot: snapshot,
        version: 'v1',
        checkoutKey: 'checkout-key',
        paymentKey: 'payment-key'));
    var creates = 0, declarations = 0;
    await expectLater(
        YapeRecoveryService(store).resume(createOrder: (_) async {
          creates++;
          return 'another-order';
        }, declare: (_) async {
          declarations++;
        }),
        throwsStateError);
    expect(creates, 0);
    expect(declarations, 0);
    expect(await store.read(), isNotNull);
    expect(
        await YapeRecoveryStore('tenant', 'user', origin: 'http://localhost')
            .read(),
        isNull);
  });
}
