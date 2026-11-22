import 'package:delivery_customer/features/courier/presentation/courier_delivery_code_section.dart';
import 'package:delivery_customer/features/courier/presentation/courier_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza el código del cliente', () {
    expect(normalizeDeliveryCode(' k7p-3m '), 'K7P3M');
  });

  test('"Pedido entregado" requiere el código validado tras la llegada', () {
    expect(
        canAdvanceCourierDelivery('ARRIVED_AT_CUSTOMER', codeVerified: false),
        isFalse);
    expect(canAdvanceCourierDelivery('ARRIVED_AT_CUSTOMER', codeVerified: true),
        isTrue);
    expect(
        canAdvanceCourierDelivery('IN_TRANSIT', codeVerified: true), isFalse);
    expect(canAdvanceCourierDelivery('ACCEPTED', codeVerified: false), isTrue);
  });

  testWidgets('valida el código y muestra el error del servidor',
      (tester) async {
    final sent = <String>[];
    var verified = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => CourierDeliveryCodeSection(
            verified: verified,
            onVerify: (code) async {
              sent.add(code);
              if (code == 'K7P3M') {
                setState(() => verified = true);
                return null;
              }
              return 'Código incorrecto. Te quedan 4 intentos.';
            },
          ),
        ),
      ),
    ));

    await tester.enterText(find.byKey(const Key('delivery-code-input')), 'abc');
    await tester.tap(find.byKey(const Key('delivery-code-submit')));
    await tester.pump();
    expect(find.text('Ingresa los 5 caracteres.'), findsOneWidget);
    expect(sent, isEmpty);

    await tester.enterText(
        find.byKey(const Key('delivery-code-input')), 'aaaaa');
    await tester.tap(find.byKey(const Key('delivery-code-submit')));
    await tester.pumpAndSettle();
    expect(sent.single, 'AAAAA');
    expect(
        find.text('Código incorrecto. Te quedan 4 intentos.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('delivery-code-input')), 'k7p3m');
    await tester.tap(find.byKey(const Key('delivery-code-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delivery-code-verified')), findsOneWidget);
  });
}
