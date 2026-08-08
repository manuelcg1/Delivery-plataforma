import 'package:delivery_customer/features/courier/data/courier_repository.dart';
import 'package:delivery_customer/features/courier/presentation/courier_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CourierDelivery delivery(String id, String status, String createdAt) =>
    CourierDelivery(
      id: 'delivery-$id',
      orderId: id.padRight(8, '0'),
      status: status,
      deliveryType: 'DELIVERY',
      pickupNotes: null,
      deliveryNotes: null,
      createdAt: createdAt,
    );

void main() {
  test('inicio muestra solo las cuatro entregas más recientes', () {
    final deliveries = [
      delivery('old', 'DELIVERED', '2026-08-01T10:00:00Z'),
      delivery('new', 'DELIVERED', '2026-08-05T10:00:00Z'),
      delivery('third', 'DELIVERED', '2026-08-03T10:00:00Z'),
      delivery('active', 'IN_TRANSIT', '2026-08-08T10:00:00Z'),
      delivery('second', 'DELIVERED', '2026-08-04T10:00:00Z'),
      delivery('fourth', 'DELIVERED', '2026-08-02T10:00:00Z'),
    ];

    final recent = recentDeliveredOrders(deliveries);

    expect(recent, hasLength(4));
    expect(recent.map((item) => item.orderId), [
      'new00000',
      'second00',
      'third000',
      'fourth00',
    ]);
  });

  testWidgets('Ver todos abre una pantalla dedicada al historial',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CourierDeliveredOrdersPage(deliveries: []),
    ));

    expect(find.text('Pedidos entregados'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}
