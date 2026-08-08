import 'package:delivery_customer/core/widgets/cart_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('success feedback is visible immediately with product details',
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
        ),
        child: const Text('Agregar'),
      ));
    })));

    await tester.tap(find.text('Agregar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Producto agregado'), findsOneWidget);
    expect(find.text('1 × Hamburguesa clásica'), findsOneWidget);
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

  testWidgets('success feedback disappears after three seconds',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(
          body: TextButton(
        onPressed: () => showProductAddedSnackBar(
          ScaffoldMessenger.of(context),
          productName: 'Pizza',
          quantity: 1,
        ),
        child: const Text('Agregar'),
      ));
    })));
    await tester.tap(find.text('Agregar'));
    await tester.pump();
    expect(find.text('Producto agregado'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Producto agregado'), findsNothing);
  });

  testWidgets('rapid feedback replaces current snackbar instead of stacking',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(
          body: TextButton(
        onPressed: () {
          final messenger = ScaffoldMessenger.of(context);
          showProductAddedSnackBar(messenger,
              productName: 'Primero', quantity: 1);
          showProductAddedSnackBar(messenger,
              productName: 'Segundo', quantity: 2);
        },
        child: const Text('Agregar dos'),
      ));
    })));
    await tester.tap(find.text('Agregar dos'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('1 \u00d7 Primero'), findsNothing);
    expect(find.text('2 \u00d7 Segundo'), findsOneWidget);
  });

  testWidgets('feedback does not reappear after changing routes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(
          body: TextButton(
        onPressed: () => showProductAddedSnackBar(
          ScaffoldMessenger.of(context),
          productName: 'Pizza',
          quantity: 1,
        ),
        child: const Text('Agregar'),
      ));
    })));
    await tester.tap(find.text('Agregar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Producto agregado'), findsNothing);
    final context = tester.element(find.text('Agregar'));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Otra pantalla')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Producto agregado'), findsNothing);
  });
}
