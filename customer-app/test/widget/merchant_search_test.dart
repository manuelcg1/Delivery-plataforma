import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/home/presentation/home_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la búsqueda ignora mayúsculas y tildes', () {
    expect(normalizeSearchText('Café con Piña'), 'cafe con pina');
  });

  testWidgets('buscar en el comercio filtra sin recargar ni perder el teclado',
      (tester) async {
    var productRequests = 0;
    final api = ApiClient(
        'https://example.test', const SessionStore(FlutterSecureStorage()));
    api.dio.interceptors.clear();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      if (request.path.endsWith('/products')) productRequests++;
      handler.resolve(Response(requestOptions: request, data: [
        {
          'id': 'torta',
          'name': 'Torta Chocolate',
          'description': '',
          'price': 13,
          'currency': 'PEN'
        },
        {
          'id': 'cafe',
          'name': 'Café americano',
          'description': '',
          'price': 3,
          'currency': 'PEN'
        },
      ]));
    }));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(CustomerRepository(api)),
          favoritesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
            home: MerchantPage(
                merchant: Merchant(
          id: 'merchant',
          code: 'M',
          name: 'Pastelería',
          description: '',
          branchId: 'branch',
          branchName: 'Principal',
          currency: 'PEN',
        )))));
    await tester.pumpAndSettle();

    final search = find.byType(SearchBar);
    await tester.tap(search);
    await tester.enterText(search, 'cafe');
    await tester.pump();

    // El buscador sigue en pantalla y con el foco: no aparece la carga.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SearchBar), findsOneWidget);
    expect(tester.testTextInput.isVisible || tester.testTextInput.hasAnyClients,
        isTrue);

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Café americano'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Café americano'), findsOneWidget);
    expect(find.text('Torta Chocolate'), findsNothing);
    expect(productRequests, 1);
  });
}
