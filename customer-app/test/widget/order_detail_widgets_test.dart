import 'package:delivery_customer/features/orders/presentation/order_detail_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in [
    'PENDING',
    'ASSIGNED',
    'ACCEPTED',
    'PICKED_UP',
    'IN_TRANSIT',
    'ARRIVED_AT_CUSTOMER',
    'DELIVERED',
    'CANCELLED',
    'FAILED',
    'REJECTED',
    'EXPIRED',
    'UNKNOWN'
  ]) {
    testWidgets('chat visible exclusively en camino: $status', (tester) async {
      var opened = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OrderCourierChatButton(
                  status: status,
                  deliveryId: 'delivery',
                  onPressed: () => opened = true))));
      final button = find.text('Chatear con el repartidor');
      expect(button, status == 'IN_TRANSIT' ? findsOneWidget : findsNothing);
      if (status == 'IN_TRANSIT') {
        await tester.tap(button);
        expect(opened, isTrue);
      }
    });
  }

  testWidgets('chat hidden without a delivery', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderCourierChatButton(
                status: 'IN_TRANSIT', deliveryId: null, onPressed: () {}))));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('summary respects theme and fits narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scheme = ColorScheme.fromSeed(seedColor: Colors.orange);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
                body: ListView(children: const [
              OrderDetailSummary(
                  number: 'ORD-1794088132160-2CE-LONG-REFERENCE',
                  statusLabel: 'Pedido creado',
                  currency: 'PEN',
                  total: 58),
              OrderCourierInfo(
                  name:
                      'Un nombre de repartidor muy largo para verificar el diseño'),
              OrderTimelineEntry(
                  title: 'Repartidor asignado',
                  date: '07/11/2026 16:50',
                  last: false),
              OrderTimelineEntry(
                  title: 'Pedido creado', date: '07/11/2026 17:05', last: true),
            ])))));
    expect(find.text('PEN 58.00'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Pedido creado').first).style?.color,
        scheme.primary);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('07/11/2026 17:05'), 150);
    expect(tester.takeException(), isNull);
  });
}
