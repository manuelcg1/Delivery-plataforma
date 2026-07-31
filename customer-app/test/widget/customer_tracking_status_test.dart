import 'package:delivery_customer/features/customer_tracking/domain/customer_tracking_response.dart';
import 'package:delivery_customer/features/customer_tracking/presentation/customer_order_tracking_page.dart';
import 'package:delivery_customer/features/customer_tracking/presentation/customer_tracking_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra reconexión y polling de respaldo', (tester) async {
    await tester.pumpWidget(wrap(const CustomerTrackingState(
      reconnecting: true,
      polling: true,
      trackingActive: true,
      stale: false,
    )));
    expect(find.text('Reconectando seguimiento…'), findsOneWidget);
    expect(find.text('Actualizando ubicación periódicamente'), findsOneWidget);
  });

  testWidgets('muestra advertencia stale', (tester) async {
    await tester.pumpWidget(wrap(const CustomerTrackingState(
      trackingActive: true,
      stale: true,
    )));
    expect(find.text('Ubicación desactualizada'), findsOneWidget);
  });

  testWidgets('muestra pedido entregado y seguimiento detenido',
      (tester) async {
    await tester.pumpWidget(wrap(const CustomerTrackingState(
      trackingActive: false,
      stale: false,
      tracking: CustomerOrderTracking(
        orderId: 'order',
        deliveryStatus: 'DELIVERED',
        trackingActive: false,
        stale: false,
      ),
    )));
    expect(find.text('Pedido entregado'), findsOneWidget);
  });

  testWidgets('muestra error de autorización y reintento', (tester) async {
    await tester.pumpWidget(wrap(const CustomerTrackingState(
      error: 'No tienes permiso para consultar este pedido.',
    )));
    expect(find.text('No tienes permiso para consultar este pedido.'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

Widget wrap(CustomerTrackingState state) => MaterialApp(
      home: Scaffold(
        body: CustomerTrackingStatusPanel(state: state, onRetry: () {}),
      ),
    );
