import 'package:delivery_customer/features/courier/data/courier_repository.dart';
import 'package:delivery_customer/features/courier/presentation/courier_route_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapea la ruta almacenada y los datos de entrega', () {
    final route = CourierDeliveryRoute.fromJson({
      'deliveryId': 'delivery',
      'orderId': 'order',
      'deliveryStatus': 'PICKED_UP',
      'orderNumber': 'CERKA-2485',
      'customerName': 'Juan Pérez',
      'destinationAddress': 'Av. Larco 245',
      'originLatitude': -12.1,
      'originLongitude': -77.1,
      'destinationLatitude': -12.2,
      'destinationLongitude': -77.2,
      'routePolyline': 'polyline',
      'routeProvider': 'OSRM',
      'distanceKm': 3.8,
      'etaMinutes': 12,
    });

    expect(route.hasOrigin, isTrue);
    expect(route.hasDestination, isTrue);
    expect(route.routePolyline, 'polyline');
    expect(route.routeProvider, 'OSRM');
    expect(route.distanceKm, 3.8);
    expect(route.etaMinutes, 12);
  });

  test('navegación usa Google, luego Waze y finalmente web', () async {
    final attempted = <Uri>[];
    final opened =
        await openCourierNavigation(-12.2, -77.2, launcher: (uri) async {
      attempted.add(uri);
      return attempted.length == 3;
    });

    expect(opened, 'Google Maps Web');
    expect(attempted, hasLength(3));
    expect(attempted[1].scheme, 'waze');
    expect(attempted[2].host, 'www.google.com');
  });

  testWidgets('pedido muestra la orden, se contrae y conserva navegación',
      (tester) async {
    final route = CourierDeliveryRoute.fromJson({
      'deliveryId': 'delivery',
      'orderId': 'order',
      'deliveryStatus': 'IN_TRANSIT',
      'orderNumber': 'CERKA-2485',
      'customerName': 'María Torres',
      'customerPhone': '+51 987 654 321',
      'destinationAddress': 'Av. Arequipa 2450, Lince',
      'destinationReference': 'Departamento 302',
      'destinationLatitude': -12.2,
      'destinationLongitude': -77.2,
      'distanceKm': 2.4,
      'etaMinutes': 8,
    });
    (double, double)? destination;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CourierOrderCard(
            route: route,
            navigationLauncher: (latitude, longitude) async {
              destination = (latitude, longitude);
              return 'Google Maps';
            },
          ),
        ),
      ),
    ));

    expect(find.text('Pedido'), findsOneWidget);
    expect(find.text('CERKA-2485'), findsOneWidget);
    expect(find.text('María Torres'), findsNWidgets(2));
    expect(find.text('Ir al destino'), findsOneWidget);
    expect(find.byTooltip('Contraer pedido'), findsOneWidget);

    await tester.tap(find.text('Pedido'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Expandir pedido'), findsOneWidget);
    expect(find.text('Ir al destino'), findsOneWidget);

    await tester.tap(find.text('Ir al destino'));
    await tester.pump();

    expect(destination, (-12.2, -77.2));
  });
}
