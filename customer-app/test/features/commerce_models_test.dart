import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';

void main() {
  test('empty cart has no stale items or total', () {
    final cart = Cart.empty(currency: 'PEN');

    expect(cart.items, isEmpty);
    expect(cart.total, 0);
    expect(cart.currency, 'PEN');
  });

  test('cleared cart cache resets merchant branch identifiers and totals', () {
    final cached = emptyCartCache(currency: 'PEN');
    final cart = Cart.fromJson(cached);

    expect(cart.items, isEmpty);
    expect(cart.merchantId, isEmpty);
    expect(cart.branchId, isEmpty);
    expect(cart.total, 0);
    expect(cached['subtotal'], 0);
    expect(cached['deliveryFee'], 0);
  });

  test('maps server cart totals without trusting local prices', () {
    final cart = Cart.fromJson({
      'items': [
        {'id': 'i1', 'productName': 'Pollo', 'quantity': 2, 'subtotal': 40}
      ],
      'total': 45.5,
      'currency': 'PEN'
    });
    expect(cart.items.single.quantity, 2);
    expect(cart.total, 45.5);
  });
  test('maps tenant identity required by realtime subscriptions', () {
    final order = Order.fromJson({
      'id': 'o1',
      'orderNumber': 'ORD-1',
      'status': 'CONFIRMED',
      'total': 30,
      'currency': 'PEN',
      'createdAt': '2026-07-21T14:30:00Z'
    });
    expect(order.status, 'CONFIRMED');
    expect(order.createdAt, '2026-07-21T14:30:00Z');
  });
  test('maps delivery events used by the customer timeline', () {
    final event = DeliveryStatusEvent.fromJson({
      'id': 'event-1',
      'status': 'IN_TRANSIT',
      'createdAt': '2026-07-22T15:45:00Z',
    });
    expect(event.status, 'IN_TRANSIT');
    expect(event.createdAt, '2026-07-22T15:45:00Z');
  });

  test('maps optional merchant logo and banner urls', () {
    final merchant = Merchant.fromJson({
      'id': 'merchant-1',
      'code': 'tienda',
      'name': 'Tienda',
      'description': 'Descripción',
      'branchId': 'branch-1',
      'branchName': 'Principal',
      'currency': 'PEN',
      'logoUrl': 'https://media.example/logo.webp',
      'bannerUrl': 'https://media.example/banner.webp',
    });

    expect(merchant.logoUrl, endsWith('logo.webp'));
    expect(merchant.bannerUrl, endsWith('banner.webp'));
  });

  test('keeps backward compatibility when merchant images are absent', () {
    final merchant = Merchant.fromJson({
      'id': 'merchant-1',
      'code': 'tienda',
      'name': 'Tienda',
      'description': '',
      'branchId': 'branch-1',
      'branchName': 'Principal',
      'currency': 'PEN',
    });

    expect(merchant.logoUrl, isNull);
    expect(merchant.bannerUrl, isNull);
  });

  test('maps product images and selects the declared primary image', () {
    final product = Product.fromJson({
      'id': 'product-1',
      'name': 'Producto',
      'description': 'Descripción',
      'price': 12.5,
      'currency': 'PEN',
      'images': [
        {
          'id': 'secondary',
          'url': 'https://media.example/secondary.webp',
          'altText': '',
          'sortOrder': 1,
          'primaryImage': false,
        },
        {
          'id': 'primary',
          'url': 'https://media.example/primary.webp',
          'altText': 'Producto',
          'sortOrder': 0,
          'primaryImage': true,
        },
      ],
    });

    expect(product.images, hasLength(2));
    expect(product.primaryImage?.id, 'primary');
  });

  test('keeps product image compatibility with older catalog responses', () {
    final product = Product.fromJson({
      'id': 'product-1',
      'name': 'Producto',
      'description': '',
      'price': 12.5,
      'currency': 'PEN',
    });

    expect(product.images, isEmpty);
    expect(product.primaryImage, isNull);
  });

  test('maps required product options and their server prices', () {
    final product = Product.fromJson({
      'id': 'product-1','name': 'Pizza','description': '',
      'price': 20,'currency': 'PEN','optionGroups': [
        {'id':'group-1','name':'Tamaño','selectionType':'SINGLE','required':true,'minimumSelections':1,'maximumSelections':1,'items':[
          {'id':'item-1','name':'Grande','priceAdjustment':5}
        ]}
      ]
    });
    expect(product.optionGroups.single.required, isTrue);
    expect(product.optionGroups.single.items.single.priceAdjustment, 5);
  });

  test('maps option snapshots returned with a cart item', () {
    final item=CartItem.fromJson({'id':'cart-item','productName':'Pizza','quantity':1,'subtotal':25,'options':[
      {'itemName':'Grande','priceAdjustment':5}
    ]});
    expect(item.options.single.name, 'Grande');
    expect(item.options.single.priceAdjustment, 5);
  });
}
