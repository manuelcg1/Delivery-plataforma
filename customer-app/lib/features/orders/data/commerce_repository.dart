import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_client.dart';
import '../../../core/offline/offline_cache.dart';

const checkoutPaymentMethods = <String, String>{
  'CARD': 'Pago con tarjeta (simulado)',
  'CASH_ON_DELIVERY': 'Pago contra entrega',
};

class CartItem {
  const CartItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.subtotal,
  });
  final String id, name;
  final int quantity;
  final double subtotal;
  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: j['id'] as String,
        name: j['productName'] as String,
        quantity: j['quantity'] as int,
        subtotal: (j['subtotal'] as num).toDouble(),
      );
}

class Cart {
  const Cart({
    required this.items,
    required this.total,
    required this.currency,
    required this.merchantId,
    required this.branchId,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.deliveryFee,
  });
  final List<CartItem> items;
  final double total;
  final double subtotal, discount, tax, deliveryFee;
  final String currency, merchantId, branchId;
  factory Cart.empty({String currency = 'PEN'}) => Cart(
        items: const [],
        total: 0,
        currency: currency,
        merchantId: '',
        branchId: '',
        subtotal: 0,
        discount: 0,
        tax: 0,
        deliveryFee: 0,
      );
  factory Cart.fromJson(Map<String, dynamic> j) => Cart(
        items: (j['items'] as List<dynamic>)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num).toDouble(),
        currency: j['currency'] as String,
        merchantId: j['merchantId']?.toString() ?? '',
        branchId: j['branchId']?.toString() ?? '',
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        tax: (j['tax'] as num?)?.toDouble() ?? 0,
        deliveryFee: (j['deliveryFee'] as num?)?.toDouble() ?? 0,
      );
}

class CoverageResult {
  const CoverageResult(
      {required this.covered,
      this.deliveryFee,
      this.estimatedMinutes,
      this.minimumEstimatedMinutes,
      this.maximumEstimatedMinutes,
      this.zoneId,
      this.reasonCode,
      this.message,
      this.distanceKm,
      this.baseFee,
      this.feePerKm,
      this.minimumFee,
      this.maximumFee,
      this.freeDeliveryThreshold,
      this.minimumOrderAmount,
      this.freeDeliveryApplied = false,
      this.fallbackApplied = false,
      this.quotedAt});
  final bool covered;
  final double? deliveryFee;
  final int? estimatedMinutes;
  final int? minimumEstimatedMinutes, maximumEstimatedMinutes;
  final double? distanceKm, baseFee, feePerKm, minimumFee, maximumFee;
  final double? freeDeliveryThreshold, minimumOrderAmount;
  final bool freeDeliveryApplied, fallbackApplied;
  final String? quotedAt;
  final String? zoneId, reasonCode, message;
  factory CoverageResult.fromJson(Map<String, dynamic> json) => CoverageResult(
      covered: json['covered'] as bool,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      estimatedMinutes: json['estimatedMinutes'] as int?,
      minimumEstimatedMinutes: json['minimumEstimatedMinutes'] as int?,
      maximumEstimatedMinutes: json['maximumEstimatedMinutes'] as int?,
      zoneId: json['zoneId'] as String?,
      reasonCode: json['reasonCode'] as String?,
      message: json['message'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      baseFee: (json['baseFee'] as num?)?.toDouble(),
      feePerKm: (json['feePerKm'] as num?)?.toDouble(),
      minimumFee: (json['minimumFee'] as num?)?.toDouble(),
      maximumFee: (json['maximumFee'] as num?)?.toDouble(),
      freeDeliveryThreshold:
          (json['freeDeliveryThreshold'] as num?)?.toDouble(),
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble(),
      freeDeliveryApplied: json['freeDeliveryApplied'] as bool? ?? false,
      fallbackApplied: json['fallbackApplied'] as bool? ?? false,
      quotedAt: json['quotedAt'] as String?);
}

String coverageMessageForCode(String? code) => switch (code) {
      'COVERAGE_NOT_CONFIGURED' =>
        'Esta sucursal todavía no tiene una zona de reparto configurada.',
      'BRANCH_LOCATION_MISSING' ||
      'BRANCH_COORDINATES_MISSING' =>
        'Esta sucursal todavía no tiene una ubicación configurada.',
      'ADDRESS_COORDINATES_MISSING' ||
      'ADDRESS_NOT_RESOLVED' =>
        'No pudimos validar esta dirección. Edítala o selecciona otra.',
      'OUTSIDE_COVERAGE' ||
      'DELIVERY_NOT_COVERED' ||
      'DELIVERY_OUT_OF_COVERAGE' =>
        'Este comercio todavía no realiza entregas en esta ubicación.',
      _ => 'No pudimos verificar la cobertura. Intenta nuevamente.',
    };

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
    required this.ratingSubmitted,
  });
  final String id, number, status, currency, createdAt;
  final double total;
  final bool ratingSubmitted;
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        number: j['orderNumber'] as String,
        status: j['status'] as String,
        total: (j['total'] as num).toDouble(),
        currency: j['currency'] as String,
        createdAt: j['createdAt'] as String,
        ratingSubmitted: j['ratingSubmitted'] as bool? ?? false,
      );
}

bool canRateOrder(Order order, {String? currentStatus}) =>
    (currentStatus ?? order.status) == 'DELIVERED' && !order.ratingSubmitted;

class ChatMessage {
  const ChatMessage(
      {required this.id,
      required this.deliveryId,
      required this.senderType,
      required this.message,
      required this.createdAt});
  final String id, deliveryId, senderType, message, createdAt;
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
      id: json['id'] as String,
      deliveryId: json['deliveryId'] as String,
      senderType: json['senderType'] as String,
      message: json['message'] as String,
      createdAt: json['createdAt'] as String);
}

class CustomerNotification {
  const CustomerNotification(
      {required this.id,
      required this.title,
      required this.body,
      required this.createdAt});
  final String id, title, body, createdAt;
  factory CustomerNotification.fromJson(Map<String, dynamic> json) =>
      CustomerNotification(
          id: json['id'] as String,
          title: json['title'] as String,
          body: json['body'] as String,
          createdAt: json['createdAt'] as String);
}

class DeliveryStatusEvent {
  const DeliveryStatusEvent({
    required this.id,
    required this.status,
    required this.createdAt,
  });
  final String id, status, createdAt;
  factory DeliveryStatusEvent.fromJson(Map<String, dynamic> json) =>
      DeliveryStatusEvent(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
      );
}

class CommerceRepository {
  CommerceRepository(this.api);
  final ApiClient api;
  String errorMessage(Object error) => api.exception(error).message;
  String errorCode(Object error) => api.exception(error).code;
  String coverageErrorMessage(Object error) =>
      coverageMessageForCode(api.exception(error).code);
  Future<Cart> cart() async {
    try {
      final r = await api.dio.get<Map<String, dynamic>>('/api/v1/cart');
      await OfflineCache.write('cart:last', r.data!);
      return Cart.fromJson(r.data!);
    } catch (error) {
      final cached = await OfflineCache.read('cart:last');
      if (cached is Map<String, dynamic>) return Cart.fromJson(cached);
      rethrow;
    }
  }

  Future<Cart> add({
    required String merchantId,
    required String branchId,
    required String productId,
    int quantity = 1,
  }) async {
    final r = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/cart/items',
      data: {
        'merchantId': merchantId,
        'branchId': branchId,
        'productId': productId,
        'quantity': quantity,
      },
    );
    await OfflineCache.write('cart:last', r.data!);
    return Cart.fromJson(r.data!);
  }

  Future<Cart> updateItem(String id, int quantity) async {
    final response = await api.dio.put<Map<String, dynamic>>(
        '/api/v1/cart/items/$id',
        data: {'quantity': quantity});
    await OfflineCache.write('cart:last', response.data!);
    return Cart.fromJson(response.data!);
  }

  Future<Cart> removeItem(String id) async {
    final response =
        await api.dio.delete<Map<String, dynamic>>('/api/v1/cart/items/$id');
    await OfflineCache.write('cart:last', response.data!);
    return Cart.fromJson(response.data!);
  }

  Future<void> clearCart() async {
    await api.dio.delete<void>('/api/v1/cart');
    await OfflineCache.write('cart:last', emptyCartCache());
  }

  Future<Order> checkout(String addressId, double expectedDeliveryFee) async {
    final r = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/orders',
      data: {
        'deliveryAddressId': addressId,
        'expectedDeliveryFee': expectedDeliveryFee,
      },
      options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
    );
    final order = Order.fromJson(r.data!);
    // The backend changes the active cart to CHECKED_OUT. Keep the offline
    // fallback in sync so a later CART_NOT_FOUND cannot restore old items.
    await OfflineCache.write(
        'cart:last', emptyCartCache(currency: order.currency));
    return order;
  }

  Future<CoverageResult> coverage(String merchantId, String addressId) async {
    final response = await api.dio.post<Map<String, dynamic>>(
        '/api/v1/customer/checkout/coverage',
        data: {'merchantId': merchantId, 'addressId': addressId});
    return CoverageResult.fromJson(response.data!);
  }

  Future<void> pay(String orderId, String method) async {
    await api.dio.post<Map<String, dynamic>>(
      '/api/v1/orders/$orderId/payments',
      data: {'paymentMethod': method},
      options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
    );
  }

  Future<List<Order>> orders() async {
    try {
      final r = await api.dio.get<List<dynamic>>('/api/v1/orders');
      await OfflineCache.write('orders:last', r.data!);
      return r.data!
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      final cached = await OfflineCache.read('orders:last');
      if (cached is List<dynamic>)
        return cached
            .map((e) => Order.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> tracking(String id) async {
    try {
      final r = await api.dio
          .get<Map<String, dynamic>>('/api/v1/orders/$id/tracking');
      await OfflineCache.write('tracking:$id', r.data!);
      return r.data!;
    } catch (error) {
      final cached = await OfflineCache.read('tracking:$id');
      if (cached is Map<String, dynamic>) return cached;
      rethrow;
    }
  }

  Future<List<DeliveryStatusEvent>> deliveryHistory(String deliveryId) async {
    final response = await api.dio
        .get<List<dynamic>>('/api/v1/deliveries/$deliveryId/history');
    return response.data!
        .map((item) =>
            DeliveryStatusEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> rate(String orderId, int score, String comment) async {
    await api.dio.post<void>('/api/v1/customer/orders/$orderId/rating',
        data: {'score': score, 'comment': comment});
    final cached = await OfflineCache.read('orders:last');
    if (cached is List<dynamic>) {
      final updated = cached.map((item) {
        final order = Map<String, dynamic>.from(item as Map);
        if (order['id'] == orderId) order['ratingSubmitted'] = true;
        return order;
      }).toList();
      await OfflineCache.write('orders:last', updated);
    }
  }

  Future<List<ChatMessage>> messages(String deliveryId) async {
    final response = await api.dio.get<List<dynamic>>('/api/v1/chat/history',
        queryParameters: {
          'deliveryId': deliveryId,
          'channel': 'CUSTOMER_COURIER'
        });
    return response.data!
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(String deliveryId, String message) async {
    final response = await api.dio
        .post<Map<String, dynamic>>('/api/v1/chat/messages', data: {
      'deliveryId': deliveryId,
      'channel': 'CUSTOMER_COURIER',
      'message': message
    });
    return ChatMessage.fromJson(response.data!);
  }

  Future<List<CustomerNotification>> notifications() async {
    final response = await api.dio.get<List<dynamic>>('/api/v1/notifications');
    return response.data!
        .map((item) =>
            CustomerNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

Map<String, dynamic> emptyCartCache({String currency = 'PEN'}) => {
      'id': '',
      'merchantId': '',
      'branchId': '',
      'items': <Object>[],
      'subtotal': 0,
      'discount': 0,
      'tax': 0,
      'deliveryFee': 0,
      'total': 0,
      'currency': currency,
      'notes': null,
    };
