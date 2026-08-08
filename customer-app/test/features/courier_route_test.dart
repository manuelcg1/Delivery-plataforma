import 'package:delivery_customer/features/courier/data/courier_repository.dart';
import 'package:delivery_customer/features/courier/presentation/courier_route_section.dart';
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
    final opened = await openCourierNavigation(-12.2, -77.2,
        launcher: (uri) async {
      attempted.add(uri);
      return attempted.length == 3;
    });

    expect(opened, 'Google Maps Web');
    expect(attempted, hasLength(3));
    expect(attempted[1].scheme, 'waze');
    expect(attempted[2].host, 'www.google.com');
  });
}
