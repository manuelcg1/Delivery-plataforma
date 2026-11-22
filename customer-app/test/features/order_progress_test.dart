import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/orders/presentation/order_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String current(List<OrderProgressStep> steps) =>
    steps.lastWhere((step) => step.done).title;

void main() {
  test('pedido recién creado muestra todos los pasos pendientes', () {
    final steps = customerOrderProgress(orderStatus: 'PENDING', history: const [
      OrderHistoryEntry(status: 'PENDING', createdAt: '2026-11-21T14:00:00Z'),
    ]);
    expect(steps, hasLength(9));
    expect(current(steps), 'Pedido creado');
    expect(steps.first.date, isNotNull);
    expect(steps.where((step) => step.done), hasLength(1));
  });

  test('antes de tener repartidor sigue los estados del comercio', () {
    expect(current(customerOrderProgress(orderStatus: 'CONFIRMED')),
        'Aceptado por el comercio');
    expect(current(customerOrderProgress(orderStatus: 'PREPARING')),
        'En preparación');
    // La entrega existe pero aún sin repartidor: no retrocede a "Pedido creado".
    expect(
        current(customerOrderProgress(
            orderStatus: 'READY', deliveryStatus: 'PENDING')),
        'Listo para recoger');
    // Oferta pendiente: todavía no cuenta como asignado.
    expect(
        current(customerOrderProgress(
            orderStatus: 'READY', deliveryStatus: 'ASSIGNED')),
        'Listo para recoger');
  });

  test('los estados de la entrega hacen avanzar el recorrido', () {
    expect(
        current(customerOrderProgress(
            orderStatus: 'READY', deliveryStatus: 'ACCEPTED')),
        'Repartidor asignado');
    expect(
        current(customerOrderProgress(
            orderStatus: 'ON_THE_WAY', deliveryStatus: 'IN_TRANSIT')),
        'En camino');
    expect(
        current(customerOrderProgress(
            orderStatus: 'ON_THE_WAY', deliveryStatus: 'ARRIVED_AT_CUSTOMER')),
        'Tu repartidor llegó');
    final delivered = customerOrderProgress(
        orderStatus: 'DELIVERED', deliveryStatus: 'DELIVERED');
    expect(delivered.every((step) => step.done), isTrue);
    expect(delivered.any((step) => step.current), isFalse);
  });

  test('un pedido cancelado termina en un paso de error', () {
    final steps =
        customerOrderProgress(orderStatus: 'CANCELLED', history: const [
      OrderHistoryEntry(status: 'PENDING', createdAt: '2026-11-21T14:00:00Z'),
      OrderHistoryEntry(status: 'CONFIRMED', createdAt: '2026-11-21T14:05:00Z'),
      OrderHistoryEntry(status: 'CANCELLED', createdAt: '2026-11-21T14:10:00Z'),
    ]);
    expect(steps.map((step) => step.title).toList(),
        ['Pedido creado', 'Aceptado por el comercio', 'Pedido cancelado']);
    expect(steps.last.failed, isTrue);
  });

  testWidgets('la línea de tiempo muestra la hora y el paso actual',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrderProgressTimeline(
              steps: customerOrderProgress(orderStatus: 'CONFIRMED')),
        ),
      ),
    ));
    expect(find.text('Seguimiento de tu pedido'), findsOneWidget);
    expect(find.text('Aceptado por el comercio'), findsOneWidget);
    expect(find.text('Ahora'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
  });

  test('el pedido lee el historial que envía el backend', () {
    final order = Order.fromJson({
      'id': 'o',
      'orderNumber': 'CK-JM6G3T',
      'status': 'PENDING',
      'total': 17,
      'currency': 'PEN',
      'createdAt': '2026-11-21T14:00:00Z',
      'history': [
        {'id': 'h', 'status': 'PENDING', 'createdAt': '2026-11-21T14:00:00Z'}
      ],
    });
    expect(order.history.single.status, 'PENDING');
  });
}
