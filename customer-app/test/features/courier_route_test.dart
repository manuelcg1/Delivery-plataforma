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
    String? called;
    var chatted = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CourierOrderCard(
            route: route,
            onChat: () => chatted = true,
            navigationLauncher: (latitude, longitude) async {
              destination = (latitude, longitude);
              return 'Google Maps';
            },
            phoneLauncher: (phone) async {
              called = phone;
              return true;
            },
          ),
        ),
      ),
    ));

    // Cabecera compacta: número y estado; el cliente aparece una sola vez.
    expect(find.text('CERKA-2485'), findsOneWidget);
    expect(find.text('En camino'), findsWidgets);
    expect(find.text('María Torres'), findsOneWidget);
    expect(find.text('2.4 km · 8 min'), findsOneWidget);
    expect(find.text('Ref.: Departamento 302'), findsOneWidget);

    // "Ir al destino" y "Chatear" comparten la fila.
    expect(tester.getCenter(find.text('Ir al destino del cliente')).dy,
        tester.getCenter(find.text('Chatear')).dy);

    await tester.tap(find.text('Ir al destino del cliente'));
    await tester.pump();
    expect(destination, (-12.2, -77.2));

    await tester.tap(find.byTooltip('Llamar al cliente'));
    await tester.pump();
    expect(called, '+51 987 654 321');

    await tester.tap(find.text('Chatear'));
    expect(chatted, isTrue);
  });

  test('el progreso horizontal sigue el estado de la entrega', () {
    expect(courierProgressRank('ASSIGNED'), 0);
    expect(courierProgressRank('ARRIVED_AT_MERCHANT'), 1);
    expect(courierProgressRank('IN_TRANSIT'), 3);
    expect(courierProgressRank('ARRIVED_AT_CUSTOMER'), 4);
    expect(courierStatusLabel('ARRIVED_AT_CUSTOMER'), 'Llegaste');
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

    // Aún no está "En camino": no se puede navegar al cliente.
    expect(find.text('Ir al destino del cliente'), findsNothing);
    expect(opened, hasLength(1));
  });

  test('solo "En camino" habilita ir al destino del cliente', () {
    expect(canNavigateToCustomer('IN_TRANSIT'), isTrue);
    for (final status in [
      'ASSIGNED',
      'ACCEPTED',
      'ARRIVED_AT_MERCHANT',
      'PICKED_UP',
      'ARRIVED_AT_CUSTOMER',
      'DELIVERED',
    ]) {
      expect(canNavigateToCustomer(status), isFalse, reason: status);
    }
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
