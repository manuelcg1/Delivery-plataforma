import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_customer/core/widgets/app_states.dart';

void main() {
  testWidgets('empty state explains the next action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyState(
          title: 'Sin pedidos',
          message: 'Realiza tu primer pedido.',
        ),
      ),
    );
    expect(find.text('Sin pedidos'), findsOneWidget);
    expect(find.text('Realiza tu primer pedido.'), findsOneWidget);
  });
}
