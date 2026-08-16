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
      'merchantName': 'Sucursal Centro',
      'merchantDisplayName': 'Restaurante El Buen Sabor',
      'branchName': 'Sucursal Centro',
      'merchantAddress': 'Av. España 1245',
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
    expect(route.merchantDisplayName, 'Restaurante El Buen Sabor');
    expect(route.branchName, 'Sucursal Centro');
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

  testWidgets('aceptado muestra comercio y abre la ubicación de recojo',
      (tester) async {
    final route = CourierDeliveryRoute.fromJson({
      'deliveryId': 'delivery',
      'orderId': 'order',
      'deliveryStatus': 'ACCEPTED',
      'orderNumber': 'CERKA-2485',
      'merchantName': 'Sucursal Centro',
      'merchantDisplayName': 'Restaurante El Buen Sabor',
      'branchName': 'Sucursal Centro',
      'merchantAddress': 'Av. España 1245, Trujillo',
      'originLatitude': -8.1116,
      'originLongitude': -79.0288,
      'destinationLatitude': -8.125,
      'destinationLongitude': -79.038,
    });
    final opened = <(double, double)>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CourierOrderCard(
            route: route,
            navigationLauncher: (latitude, longitude) async {
              opened.add((latitude, longitude));
              return 'Google Maps';
            },
          ),
        ),
      ),
    ));

    expect(find.text('PUNTO DE RECOJO'), findsOneWidget);
    expect(find.text('Restaurante El Buen Sabor · Sucursal Centro'),
        findsOneWidget);
    expect(find.text('Av. España 1245, Trujillo'), findsOneWidget);

    await tester.tap(find.text('Av. España 1245, Trujillo'));
    await tester.pump();
    expect(opened.single, (-8.1116, -79.0288));

    await tester.tap(find.text('Ir al destino'));
    await tester.pump();
    expect(opened.last, (-8.125, -79.038));
  });

  testWidgets('asignado oculta comercio y dirección sin coordenadas no enlaza',
      (tester) async {
    Future<void> pump(String status) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CourierOrderCard(
              route: CourierDeliveryRoute.fromJson({
                'deliveryId': 'delivery',
                'orderId': 'order',
                'deliveryStatus': status,
                'orderNumber': 'CERKA-2485',
                'merchantDisplayName': 'Comercio',
                'merchantAddress': 'Dirección conocida',
              }),
            ),
          ),
        ));

    await pump('ASSIGNED');
    expect(find.text('PUNTO DE RECOJO'), findsNothing);

    await pump('ACCEPTED');
    expect(find.text('PUNTO DE RECOJO'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
  });
}
