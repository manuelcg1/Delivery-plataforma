import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OrderCard is responsive and keeps its existing tap action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tapped = false;
    const order = Order(
      id: 'order-id',
      number: 'ORD-1785793312366-CC6614',
      status: 'DELIVERED',
      total: 28,
      currency: 'PEN',
      createdAt: '2026-08-03T16:41:00Z',
      ratingSubmitted: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: OrderCard(order: order, onTap: () => tapped = true),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ORD-1785793312366-CC6614'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.text('PEN'), findsOneWidget);
    expect(find.text('28.00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(OrderCard));
    expect(tapped, isTrue);
  });
}
