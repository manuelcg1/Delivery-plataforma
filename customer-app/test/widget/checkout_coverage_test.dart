import 'package:delivery_customer/features/address/domain/customer_address.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CustomerAddress address(String text) => CustomerAddress(
      id: text,
      label: 'Casa',
      formattedAddress: text,
      latitude: -8.125,
      longitude: -79.038,
      countryCode: 'PE',
      isDefault: true,
    );

Future<void> pumpSelector(
    WidgetTester tester, double width, String text) async {
  await tester.binding.setSurfaceSize(Size(width, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: CheckoutAddressSelector(
          addresses: [address(text)],
          value: text,
          onChanged: (_) {},
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('muestra una dirección corta', (tester) async {
    await pumpSelector(tester, 390, 'Mercurio 405');
    expect(find.textContaining('Mercurio 405'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recorta una dirección larga sin overflow', (tester) async {
    await pumpSelector(tester, 390,
        'Mercurio 405, urbanización muy extensa, Trujillo 13011, Perú');
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((widget) => widget.data?.contains('Mercurio 405') ?? false);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets('selector responsivo sin overflow a ${width.toInt()} px',
        (tester) async {
      await pumpSelector(tester, width,
          'Mercurio 405, urbanización muy extensa, Trujillo 13011, Perú');
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('muestra dirección cubierta', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CheckoutCoverageStatus(
          coverage: CoverageResult(
            covered: true,
            deliveryFee: 5,
            estimatedMinutes: 30,
            message: 'Cobertura disponible',
          ),
        ),
      ),
    ));
    expect(find.text('Cobertura disponible'), findsOneWidget);
    expect(find.textContaining('30 min'), findsOneWidget);
  });

  testWidgets('muestra dirección fuera de cobertura', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CheckoutCoverageStatus(
          coverage: CoverageResult(
            covered: false,
            reasonCode: 'DELIVERY_OUT_OF_COVERAGE',
          ),
        ),
      ),
    ));
    expect(
        find.text(
            'Este comercio todavía no realiza entregas en esta ubicación.'),
        findsOneWidget);
  });

  testWidgets('muestra comercio sin zona', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CheckoutCoverageStatus(
          coverage: CoverageResult(
              covered: false, reasonCode: 'COVERAGE_NOT_CONFIGURED'),
        ),
      ),
    ));
    expect(
        find.text(
            'Esta sucursal todavía no tiene una zona de reparto configurada.'),
        findsOneWidget);
  });

  test('diferencia error de dirección y error temporal', () {
    expect(coverageMessageForCode('ADDRESS_NOT_RESOLVED'),
        'No pudimos validar esta dirección. Edítala o selecciona otra.');
    expect(coverageMessageForCode('INTERNAL_ERROR'),
        'No pudimos verificar la cobertura. Intenta nuevamente.');
  });
}
