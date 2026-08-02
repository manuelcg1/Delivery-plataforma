import 'package:delivery_customer/features/address/data/google_places_service.dart';
import 'package:delivery_customer/features/address/domain/customer_address.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  test('parses normalized backend address and typed coordinates', () {
    final address = parseAddressResult({
      'placeId': 'ChIJtest',
      'formattedAddress': 'Av. Ejército 710, Arequipa',
      'latitude': -16.3912,
      'longitude': -71.5489,
      'street': 'Avenida Ejército',
      'streetNumber': '710',
      'district': 'Yanahuara',
      'postalCode': '04013',
      'countryCode': 'PE'
    }, source: 'SEARCH');
    expect(address.placeId, 'ChIJtest');
    expect(address.latitude, -16.3912);
    expect(address.street, 'Avenida Ejército');
    expect(address.streetNumber, '710');
    expect(address.district, 'Yanahuara');
    expect(address.locationSource, 'SEARCH');
  });
  test('validates coordinate ranges', () {
    expect(validCoordinates(-16.4, -71.5), isTrue);
    expect(validCoordinates(91, 0), isFalse);
    expect(validCoordinates(0, 181), isFalse);
  });
  test('manual address may omit placeId', () {
    const address = CustomerAddress(
        id: '',
        label: 'Casa',
        formattedAddress: 'Ubicación en mapa',
        latitude: -16.4,
        longitude: -71.5,
        countryCode: 'PE',
        isDefault: false,
        locationSource: 'MAP');
    expect(address.toRequest()['placeId'], isNull);
  });
  test('address search sessions use fresh UUID tokens', () {
    final service = GooglePlacesService(Dio());
    final first = service.sessionToken;
    service.newSession();
    expect(service.sessionToken, isNot(first));
    expect(service.sessionToken.length, 36);
  });
}
