import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/errors/app_exception.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:dio/dio.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/features/address/domain/customer_address.dart';
import 'package:delivery_customer/features/home/presentation/home_page.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/orders/data/yape_checkout.dart';
import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:delivery_customer/features/orders/presentation/yape_checkout_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:delivery_customer/features/orders/data/yape_recovery.dart';

const settings = YapeSettings(
    enabled: true,
    phone: '999888777',
    holderName: 'Ana',
    qrUrl: 'https://example.com/qr',
    version: 'v1');

class CheckoutRepository extends CommerceRepository {
  CheckoutRepository()
      : super(ApiClient('https://example.test',
            const SessionStore(FlutterSecureStorage())));
  String merchant = 'merchant';
  double subtotal = 20;
  double fee = 5;
  String version = 'v1';
  int created = 0;
  String? paidVersion;
  bool paymentFails = false;
  bool open = true;
  bool availabilityFails = false;
  int availabilityCalls = 0;
  int settingsCalls = 0;
  bool hoursRejected = false;
  bool checkoutHoursRejected = false;
  @override
  String errorMessage(Object error) =>
      error is AppException ? error.message : 'Pago pendiente';
  @override
  String errorCode(Object error) => error is AppException ? error.code : '';
  @override
  Future<Cart> cart() async => Cart(
      items: const [],
      total: subtotal,
      currency: 'PEN',
      merchantId: merchant,
      branchId: 'b',
      subtotal: subtotal,
      discount: 0,
      tax: 0,
      deliveryFee: 0);
  @override
  Future<CoverageResult> coverage(String merchantId, String addressId) async =>
      hoursRejected
          ? throw const AppException('Fuera de horario de atención',
              code: 'OUTSIDE_BUSINESS_HOURS')
          : CoverageResult(covered: true, deliveryFee: fee);
  @override
  Future<YapeSettings> yapeSettings(String merchantId) async {
    settingsCalls++;
    return YapeSettings(
        enabled: true,
        phone: settings.phone,
        holderName: settings.holderName,
        qrUrl: settings.qrUrl,
        version: version);
  }

  @override
  Future<Order> checkout(String addressId, double expectedDeliveryFee) async {
    if (checkoutHoursRejected) {
      throw const AppException('Fuera de horario de atención',
          code: 'OUTSIDE_BUSINESS_HOURS');
    }
    created++;
    return const Order(
        id: 'o',
        number: '1',
        status: 'PENDING',
        total: 25,
        currency: 'PEN',
        createdAt: '',
        ratingSubmitted: false);
  }

  @override
  Future<void> payYape(String orderId, String version,
      {String? idempotencyKey}) async {
    paidVersion = version;
    if (paymentFails) throw StateError('pending');
  }
}

CustomerRepository availabilityRepository(CheckoutRepository repository) {
  final api = ApiClient(
      'https://example.test', const SessionStore(FlutterSecureStorage()));
  api.dio.interceptors.clear();
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
    repository.availabilityCalls++;
    if (repository.availabilityFails) {
      handler.reject(DioException(requestOptions: request));
      return;
    }
    handler.resolve(Response(requestOptions: request, data: {
      'branchId': 'b',
      'open': repository.open,
      'status': repository.open ? 'OPEN' : 'CLOSED',
      'timezone': 'America/Lima',
      'nextOpeningAt': null,
      'currentSchedule': null,
    }));
  }));
  return CustomerRepository(api);
}

Future<ProviderContainer> checkoutApp(
    WidgetTester tester, CheckoutRepository repository) async {
  final container = ProviderContainer(overrides: [
    commerceRepositoryProvider.overrideWithValue(repository),
    customerRepositoryProvider
        .overrideWithValue(availabilityRepository(repository)),
    addressesProvider.overrideWith((ref) async => [
          const CustomerAddress(
              id: 'a',
              label: 'Casa',
              formattedAddress: 'Calle 1',
              latitude: -8,
              longitude: -79,
              countryCode: 'PE',
              isDefault: true)
        ]),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const MaterialApp(home: CheckoutPage())));
  await tester.pumpAndSettle();
  return container;
}

Future<void> declare(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(YapeCheckoutCard));
  await tester.tap(find.byType(YapeCheckoutCard));
  await tester.pumpAndSettle();
  // Exercise the checkout boundary with the same typed result the QR panel returns.
  Navigator.of(tester.element(find.byType(YapeCheckoutSheet))).pop(settings);
  await tester.pumpAndSettle();
}

Finder get createButton => find.widgetWithText(FilledButton, 'Crear pedido');
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('pending recovery blocks a new QR before another transfer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final token = 'header.${base64Url.encode(utf8.encode(jsonEncode({
          'tenantId': 'tenant',
          'userId': 'user'
        })))}.signature';
    FlutterSecureStorage.setMockInitialValues({'access_token': token});
    final store =
        YapeRecoveryStore('tenant', 'user', origin: 'https://example.test');
    await store.save(const YapeRecoveryIntent(
        snapshot: YapeCheckoutSnapshot(
            merchantId: 'merchant',
            addressId: 'a',
            total: 25,
            deliveryFee: 5,
            currency: 'PEN'),
        version: 'v1',
        checkoutKey: 'c',
        paymentKey: 'p',
        orderId: 'existing'));
    final repository = CheckoutRepository();
    await checkoutApp(tester, repository);
    await tester.ensureVisible(find.byType(YapeCheckoutCard));
    await tester.tap(find.byType(YapeCheckoutCard));
    await tester.pumpAndSettle();
    expect(find.byType(YapeCheckoutSheet), findsNothing);
    expect(find.textContaining('declaración pendiente en Pedidos'),
        findsOneWidget);
    expect(repository.settingsCalls, 0);
    expect(repository.created, 0);
  });
  testWidgets(
      'failed declaration survives checkout and retries the same existing order',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final token = 'header.${base64Url.encode(utf8.encode(jsonEncode({
          'tenantId': 'tenant',
          'userId': 'user'
        })))}.signature';
    FlutterSecureStorage.setMockInitialValues({'access_token': token});
    final repository = CheckoutRepository()..paymentFails = true;
    await checkoutApp(tester, repository);
    await declare(tester);
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    final store =
        YapeRecoveryStore('tenant', 'user', origin: 'https://example.test');
    final pending = await store.read();
    expect(pending, isNotNull);
    expect(pending!.orderId, 'o');
    expect(repository.created, 1);
    repository.paymentFails = false;
    await YapeRecoveryService(store).resume(
        createOrder: (_) async => throw StateError('duplicate create'),
        declare: (intent) => repository.payYape(intent.orderId!, intent.version,
            idempotencyKey: intent.paymentKey));
    expect(repository.created, 1);
    expect(await store.read(), isNull);
  });
  testWidgets(
      'resume rechecks hours before reloading Yape or declaring payment',
      (tester) async {
    final repository = CheckoutRepository();
    await checkoutApp(tester, repository);
    await tester.ensureVisible(find.byType(YapeCheckoutCard));
    await tester.tap(find.byType(YapeCheckoutCard));
    await tester.pumpAndSettle();
    expect(find.byType(YapeCheckoutSheet), findsOneWidget);
    expect(repository.settingsCalls, 1);
    expect(repository.availabilityCalls, 2);
    repository.open = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.availabilityCalls, 3);
    expect(repository.settingsCalls, 1);
    expect(find.text('¿Realizaste tu Yape?'), findsNothing);
    expect(find.text('Fuera de horario de atención'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repository.availabilityCalls, 4);
    expect(repository.settingsCalls, 1);
    Navigator.of(tester.element(find.byType(YapeCheckoutSheet))).pop();
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
    expect(repository.created, 0);
  });

  for (final networkFailure in [false, true]) {
    testWidgets(
        'closed or unavailable branch blocks QR (network=$networkFailure)',
        (tester) async {
      final repository = CheckoutRepository()
        ..open = false
        ..availabilityFails = networkFailure;
      await checkoutApp(tester, repository);
      await tester.ensureVisible(find.byType(YapeCheckoutCard));
      await tester.tap(find.byType(YapeCheckoutCard));
      await tester.pumpAndSettle();
      expect(find.byType(YapeCheckoutSheet), findsNothing);
      expect(repository.availabilityCalls, 1);
      expect(repository.created, 0);
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
      expect(
          find.textContaining(
              networkFailure ? 'Intenta nuevamente' : 'Fuera de horario'),
          findsOneWidget);
    });
  }
  testWidgets('reopening requires a fresh successful QR check', (tester) async {
    final repository = CheckoutRepository()..open = false;
    await checkoutApp(tester, repository);
    await tester.ensureVisible(find.byType(YapeCheckoutCard));
    await tester.tap(find.byType(YapeCheckoutCard));
    await tester.pumpAndSettle();
    expect(find.byType(YapeCheckoutSheet), findsNothing);
    repository.open = true;
    await declare(tester);
    expect(repository.availabilityCalls, 3);
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
  });
  for (final duringCheckout in [false, true]) {
    testWidgets(
        'server hours rejection clears declaration (checkout=$duringCheckout)',
        (tester) async {
      final repository = CheckoutRepository();
      await checkoutApp(tester, repository);
      await declare(tester);
      repository.hoursRejected = !duringCheckout;
      repository.checkoutHoursRejected = duringCheckout;
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(repository.created, 0);
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
      expect(find.textContaining('Fuera de horario'), findsOneWidget);
    });
  }

  testWidgets('coverage alone cannot create; declaration enables creation',
      (tester) async {
    await checkoutApp(tester, CheckoutRepository());
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
    await declare(tester);
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    expect(
        find.text('Yape declarado · Pendiente de validación'), findsOneWidget);
  });
  for (final change in ['total', 'merchant', 'fee']) {
    testWidgets('$change change invalidates declaration', (tester) async {
      final repository = CheckoutRepository();
      final container = await checkoutApp(tester, repository);
      await declare(tester);
      if (change == 'total') repository.subtotal = 30;
      if (change == 'merchant') repository.merchant = 'other';
      if (change == 'fee') {
        repository.fee = 7;
        repository.merchant = 'other';
      }
      container.invalidate(cartProvider);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
    });
  }
  testWidgets('version changes before submit prevent order creation',
      (tester) async {
    final repository = CheckoutRepository();
    await checkoutApp(tester, repository);
    await declare(tester);
    repository.version = 'v2';
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(repository.created, 0);
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
  });
  for (final fails in [false, true]) {
    testWidgets(
        'created order preserves pending payment navigation (failure=$fails)',
        (tester) async {
      final repository = CheckoutRepository()..paymentFails = fails;
      await checkoutApp(tester, repository);
      await declare(tester);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(repository.created, 1);
      expect(repository.paidVersion, 'v1');
      if (fails)
        expect(find.textContaining('El pedido fue creado'), findsOneWidget);
    });
  }
  testWidgets('resume invalidates an earlier declaration', (tester) async {
    await checkoutApp(tester, CheckoutRepository());
    await declare(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
  });
}
