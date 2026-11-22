import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/orders/presentation/order_products.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  OrderLineItem(
    productName: 'Torta Chocolate',
    quantity: 2,
    subtotal: 26,
    options: [
      OrderLineOption(
          groupName: 'Extra', itemName: 'Fudge', priceAdjustment: 2),
    ],
    notes: 'sin nueces',
  ),
  OrderLineItem(productName: 'Café americano', quantity: 1, subtotal: 3),
];

void main() {
  test('resume productos y cuenta unidades', () {
    expect(orderItemsSummary(_items), '2× Torta Chocolate, 1× Café americano');
    expect(orderItemsCount(_items), '3 productos');
    expect(orderItemsCount(const [_single]), '1 producto');
  });

  test('lee los productos del pedido que envía el backend', () {
    final order = Order.fromJson({
      'id': 'o',
      'orderNumber': 'CK-VNW47C',
      'status': 'PREPARING',
      'total': 31,
      'subtotal': 29,
      'deliveryFee': 2,
      'currency': 'PEN',
      'createdAt': '2026-11-22T13:00:00Z',
      'items': [
        {
          'productName': 'Torta Chocolate',
          'quantity': 2,
          'subtotal': 26,
          'options': [
            {'groupName': 'Extra', 'itemName': 'Fudge', 'priceAdjustment': 2}
          ],
          'notes': 'sin nueces'
        }
      ],
    });
    expect(order.items.single.options.single.itemName, 'Fudge');
    expect(order.subtotal, 29);
    expect(order.deliveryFee, 2);
  });

  testWidgets('el cliente ve productos, opciones, notas y totales',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => OrderProductsSummaryRow(
            items: _items,
            onView: () => showOrderProductsSheet(context,
                orderNumber: 'CK-VNW47C',
                items: _items,
                currency: 'PEN',
                total: 31,
                subtotal: 29,
                deliveryFee: 2),
          ),
        ),
      ),
    ));
    expect(find.text('2× Torta Chocolate, 1× Café americano'), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-products')));
    await tester.pumpAndSettle();
    expect(find.text('Productos del pedido'), findsOneWidget);
    expect(find.text('Extra: Fudge (+S/ 2.00)'), findsOneWidget);
    expect(find.text('Nota: sin nueces'), findsOneWidget);
    expect(find.text('PEN 31.00'), findsOneWidget);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Productos del pedido'), findsNothing);
  });

  testWidgets('el repartidor revisa sin precios y marca lo recibido',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCourierProductsSheet(context,
                orderNumber: 'CK-VNW47C',
                items: _items,
                merchantName: 'Pastelería Larco'),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa el pedido antes de salir'), findsOneWidget);
    expect(find.textContaining('S/'), findsNothing);
    expect(find.textContaining('PEN'), findsNothing);
    expect(find.text('0 de 2 verificados'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('1 de 2 verificados'), findsOneWidget);
  });
}

const _single = OrderLineItem(productName: 'Pan', quantity: 1);
