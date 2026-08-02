import '../../../core/api/api_client.dart';
import '../../address/domain/customer_address.dart';

typedef Address = CustomerAddress;

Map<String, dynamic> addressRequestData({
  required String label,
  required String recipientName,
  required String phone,
  required String addressLine,
  required String district,
  required bool isDefault,
  double? latitude,
  double? longitude,
}) =>
    <String, dynamic>{
      'label': label.trim(),
      'recipientName': recipientName.trim(),
      'phone': phone.trim(),
      'formattedAddress': addressLine.trim(),
      'addressLine': addressLine.trim(),
      'district': district.trim(),
      'countryCode': 'PE',
      'latitude': latitude,
      'longitude': longitude,
      'locationSource': 'MAP',
      'isDefault': isDefault,
    };

class Merchant {
  const Merchant({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.branchId,
    required this.branchName,
    required this.currency,
  });
  final String id, code, name, description, branchId, branchName, currency;
  factory Merchant.fromJson(Map<String, dynamic> j) => Merchant(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        description: j['description']?.toString() ?? '',
        branchId: j['branchId'] as String,
        branchName: j['branchName'] as String,
        currency: j['currency'] as String,
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
  });
  final String id, name, description, currency;
  final double price;
  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description']?.toString() ?? '',
        price: (j['price'] as num).toDouble(),
        currency: j['currency'] as String,
      );
}

class Favorite {
  const Favorite(
      {required this.id,
      required this.name,
      required this.description,
      required this.merchantId,
      required this.productId});
  final String id, name, description;
  final String? merchantId, productId;
  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description']?.toString() ?? '',
      merchantId: json['merchantId'] as String?,
      productId: json['productId'] as String?);
}

Favorite? favoriteForMerchant(List<Favorite> favorites, String merchantId) {
  for (final favorite in favorites) {
    if (favorite.merchantId == merchantId) return favorite;
  }
  return null;
}

class CustomerRepository {
  CustomerRepository(this.api);
  final ApiClient api;
  Future<List<Address>> addresses() async {
    final r = await api.dio.get<List<dynamic>>('/api/v1/customer/addresses');
    return r.data!
        .map((e) => CustomerAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Address> addAddress(Map<String, dynamic> data) async {
    final r = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/customer/addresses',
      data: data,
    );
    return CustomerAddress.fromJson(r.data!);
  }

  Future<Address> updateAddress(String id, Map<String, dynamic> data) async {
    final response = await api.dio.put<Map<String, dynamic>>(
      '/api/v1/customer/addresses/$id',
      data: data,
    );
    return CustomerAddress.fromJson(response.data!);
  }

  Future<void> deleteAddress(String id) =>
      api.dio.delete<void>('/api/v1/customer/addresses/$id');

  Future<Address> makeDefaultAddress(String id) async {
    final response = await api.dio.patch<Map<String, dynamic>>(
      '/api/v1/customer/addresses/$id/default',
    );
    return CustomerAddress.fromJson(response.data!);
  }

  Future<List<Merchant>> merchants([String search = '']) async {
    final r = await api.dio.get<List<dynamic>>(
      '/api/v1/customer/merchants',
      queryParameters: {'search': search},
    );
    return r.data!
        .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> products(String branchId) async {
    final r = await api.dio.get<List<dynamic>>(
      '/api/v1/public/catalog/branches/$branchId/products',
    );
    return r.data!
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Favorite>> favorites() async {
    final response =
        await api.dio.get<List<dynamic>>('/api/v1/customer/favorites');
    return response.data!
        .map((item) => Favorite.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addMerchantFavorite(String merchantId) =>
      api.dio.post<void>('/api/v1/customer/favorites',
          data: {'merchantId': merchantId});
  Future<void> removeFavorite(String id) =>
      api.dio.delete<void>('/api/v1/customer/favorites/$id');
}
