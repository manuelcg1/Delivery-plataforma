import 'package:delivery_customer/core/widgets/cart_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('success feedback shows product and opens cart action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(
          body: FilledButton(
        onPressed: () => showProductAddedSnackBar(
          ScaffoldMessenger.of(context),
          productName: 'Hamburguesa clásica',
          quantity: 1,
          onViewCart: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const Text('Carrito abierto')),
          ),
        ),
        child: const Text('Agregar'),
      ));
    })));

    await tester.tap(find.text('Agregar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Producto agregado'), findsOneWidget);
    expect(find.text('1 × Hamburguesa clásica'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();
    expect(find.text('Carrito abierto'), findsOneWidget);
  });

  testWidgets('error feedback presents backend message', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(
          body: FilledButton(
        onPressed: () => showCartErrorSnackBar(
            ScaffoldMessenger.of(context), 'Producto sin stock'),
        child: const Text('Fallar'),
      ));
    })));
    await tester.tap(find.text('Fallar'));
    await tester.pump();
    expect(find.text('Producto sin stock'), findsOneWidget);
  });
}
