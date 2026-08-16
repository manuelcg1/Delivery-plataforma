import 'package:delivery_customer/features/customer_tracking/presentation/customer_order_tracking_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la llegada se muestra como aviso flotante y temporal',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).showSnackBar(arrivalSnackBar()),
            child: const Text('Mostrar'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Mostrar'));
    await tester.pump();

    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('¡Llegó tu pedido!'), findsOneWidget);
    expect(
      find.text('Tu repartidor ya se encuentra en el punto de entrega.'),
      findsOneWidget,
    );
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).behavior,
        SnackBarBehavior.floating);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).showCloseIcon, isTrue);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 5));
  });
}
