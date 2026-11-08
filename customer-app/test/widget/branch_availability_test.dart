import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/home/presentation/home_page.dart';
import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final state in ['CLOSED', 'OPEN', 'UNCONFIGURED', 'ERROR']) {
    testWidgets('product selection verifies fresh branch availability: $state',
        (tester) async {
      final calls = <String>[];
      final api = ApiClient(
          'https://example.test', const SessionStore(FlutterSecureStorage()));
      api.dio.interceptors.clear();
      api.dio.interceptors
          .add(InterceptorsWrapper(onRequest: (request, handler) {
        calls.add(request.path);
        if (request.path.endsWith('/availability')) {
          if (state == 'ERROR') {
            handler.reject(DioException(requestOptions: request));
            return;
          }
          handler.resolve(Response(requestOptions: request, data: {
            'branchId': 'branch',
            'open': state != 'CLOSED',
            'status': state,
            'timezone': 'America/Lima',
            'nextOpeningAt': null,
            'currentSchedule': null,
          }));
          return;
        }
        final product = {
          'id': 'product',
          'name': 'Helado especial',
          'description': '',
          'price': 10,
          'currency': 'PEN'
        };
        handler.resolve(Response(
            requestOptions: request,
            data: request.path.endsWith('/products') ? [product] : product));
      }));
      await tester.pumpWidget(ProviderScope(
          overrides: [
            customerRepositoryProvider
                .overrideWithValue(CustomerRepository(api)),
            favoritesProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
              home: MerchantPage(
                  merchant: Merchant(
            id: 'merchant',
            code: 'M',
            name: 'Tienda',
            description: '',
            branchId: 'branch',
            branchName: 'Principal',
            currency: 'PEN',
          )))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Helado especial'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Helado especial'));
      await tester.pumpAndSettle();
      expect(calls.where((path) => path.endsWith('/availability')).length, 1);
      final allowed = state == 'OPEN' || state == 'UNCONFIGURED';
      expect(find.byType(ProductPage), allowed ? findsOneWidget : findsNothing);
      expect(calls.any((path) => path.endsWith('/products/product')), allowed);
      if (!allowed) {
        expect(
            find.textContaining(
                state == 'ERROR' ? 'Intenta nuevamente' : 'Fuera de horario'),
            findsOneWidget);
        expect(find.text('Helado especial'), findsOneWidget);
      }
    });
  }
}
