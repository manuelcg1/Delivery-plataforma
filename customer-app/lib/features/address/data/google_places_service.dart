import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../domain/customer_address.dart';

class PlaceSuggestion {
  const PlaceSuggestion(this.placeId, this.description,
      {this.primaryText = '', this.secondaryText = ''});
  final String placeId, description, primaryText, secondaryText;
}

class GooglePlacesService {
  GooglePlacesService(this._dio);
  final Dio _dio;
  String _token = const Uuid().v4();
  CancelToken? _autocompleteCancel;
  String get sessionToken => _token;
  void newSession() => _token = const Uuid().v4();

  Future<List<PlaceSuggestion>> autocomplete(String query,
      {double? latitude, double? longitude}) async {
    if (query.trim().length < 3) return const [];
    _autocompleteCancel?.cancel('Nueva búsqueda');
    final cancel = CancelToken();
    _autocompleteCancel = cancel;
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/customer/address-search',
      cancelToken: cancel,
      queryParameters: {
        'query': query.trim(),
        'sessionToken': _token,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    final values = response.data?['suggestions'] as List? ?? const [];
    return values.map((raw) {
      final json = raw as Map<String, dynamic>;
      return PlaceSuggestion(
          json['placeId'] as String, json['formattedText'] as String,
          primaryText: json['primaryText']?.toString() ?? '',
          secondaryText: json['secondaryText']?.toString() ?? '');
    }).toList();
  }

  Future<CustomerAddress> details(String placeId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/customer/address-place/$placeId',
      queryParameters: {'sessionToken': _token},
    );
    final address = parseAddressResult(response.data!, source: 'SEARCH');
    newSession();
    return address;
  }

  Future<CustomerAddress> reverse(double latitude, double longitude) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/customer/address-reverse-geocode',
      queryParameters: {'latitude': latitude, 'longitude': longitude},
    );
    return parseAddressResult(response.data!, source: 'MAP');
  }
}

CustomerAddress parseAddressResult(Map<String, dynamic> json,
        {required String source}) =>
    CustomerAddress(
        id: '',
        label: 'Casa',
        formattedAddress: json['formattedAddress'] as String,
        placeId: json['placeId'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        street: json['street'] as String?,
        streetNumber: json['streetNumber'] as String?,
        district: json['district'] as String?,
        city: json['city'] as String?,
        province: json['province'] as String?,
        region: json['region'] as String?,
        postalCode: json['postalCode'] as String?,
        countryCode: json['countryCode'] as String? ?? 'PE',
        isDefault: false,
        locationSource: source);
