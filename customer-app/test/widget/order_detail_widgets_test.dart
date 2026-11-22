import 'package:delivery_customer/features/orders/presentation/order_detail_widgets.dart';
import 'package:delivery_customer/features/orders/presentation/order_progress.dart';
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
    final open = const {'IN_TRANSIT', 'ARRIVED_AT_CUSTOMER'}.contains(status);
    test('chat disponible solo con la entrega en camino: $status', () {
      expect(canChatWithCourier(status, 'delivery'), open);
    });
  }

  test('sin entrega no hay chat', () {
    expect(canChatWithCourier('IN_TRANSIT', null), isFalse);
  });

  testWidgets('seguir pedido y chatear comparten una fila', (tester) async {
    var tracked = false, chatted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderDetailActions(
                onTrack: () => tracked = true, onChat: () => chatted = true))));
    final track = tester.getCenter(find.text('Seguir pedido'));
    final chat = tester.getCenter(find.text('Chatear'));
    expect(track.dy, chat.dy);
    await tester.tap(find.text('Seguir pedido'));
    await tester.tap(find.text('Chatear'));
    expect(tracked && chatted, isTrue);
  });

  testWidgets('sin acciones disponibles no muestra botones', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: OrderDetailActions(onTrack: null, onChat: null))));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('el código de entrega es compacto y conserva el mensaje',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [DeliveryCodeCard(code: 'GC7EW')]))));
    expect(find.text('GC7EW'), findsOneWidget);
    expect(find.text(deliveryCodeSecurityMessage), findsOneWidget);
    expect(tester.getSize(find.byType(DeliveryCodeCard)).height, lessThan(110));
  });

  testWidgets('tarjetas compactas caben en pantalla angosta con texto grande',
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
                body: ListView(children: [
              const OrderDetailSummary(
                  number: 'ORD-1794088132160-2CE-LONG-REFERENCE',
                  statusLabel: 'Pedido creado',
                  currency: 'PEN',
                  total: 58),
              const OrderCourierInfo(
                  name:
                      'Un nombre de repartidor muy largo para verificar el diseño'),
              OrderProgressTimeline(
                  steps: customerOrderProgress(orderStatus: 'CONFIRMED')),
            ])))));
    expect(find.text('PEN 58.00'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Pedido creado').first).style?.color,
        scheme.primary);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Entregado'), 150);
    expect(tester.takeException(), isNull);
  });
}
