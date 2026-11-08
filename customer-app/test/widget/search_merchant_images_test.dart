import 'package:cached_network_image/cached_network_image.dart';
import 'package:delivery_customer/app/app.dart';
import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/home/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class SearchRepository extends CustomerRepository {
  SearchRepository()
      : super(ApiClient('https://example.test',
            const SessionStore(FlutterSecureStorage())));
  final searches = <String>[];
  static const stores = [
    Merchant(
        id: 'ice',
        code: 'ice',
        name: 'HELADOS',
        description: 'Helados artesanales',
        branchId: 'branch',
        branchName: 'Principal',
        currency: 'PEN',
        logoUrl: 'https://example.test/logo.png',
        bannerUrl: 'https://example.test/banner.png'),
    Merchant(
        id: 'cafe',
        code: 'cafe',
        name: 'Cafe',
        description: 'Café y panes',
        branchId: 'cafe-branch',
        branchName: 'Centro',
        currency: 'PEN')
  ];
  @override
  Future<List<Merchant>> merchants([String search = '']) async {
    searches.add(search);
    return stores
        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
  }

  @override
  Future<List<Product>> products(String branchId) async => [];
}

Future<void> showSearch(
    WidgetTester tester, SearchRepository repository) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    customerRepositoryProvider.overrideWithValue(repository),
    favoritesProvider.overrideWith((ref) async => [])
  ], child: const MaterialApp(home: Scaffold(body: SearchPage()))));
  await tester.pump();
}

void main() {
  testWidgets('Buscar uses the configured merchant logo and banner',
      (tester) async {
    await showSearch(tester, SearchRepository());
    final urls = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((image) => image.imageUrl);
    expect(
        urls,
        containsAll([
          'https://example.test/logo.png',
          'https://example.test/banner.png'
        ]));
    expect(find.text('Helados artesanales'), findsOneWidget);
  });
  testWidgets(
      'search filtering and opening a merchant remain available without images',
      (tester) async {
    final repository = SearchRepository();
    await showSearch(tester, repository);
    await tester.enterText(find.byType(TextField), 'Cafe');
    await tester.pumpAndSettle();
    expect(repository.searches, contains('Cafe'));
    expect(find.text('HELADOS'), findsNothing);
    expect(
        find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'Cafe'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Cafe'));
    await tester.pumpAndSettle();
    expect(find.byType(MerchantPage), findsOneWidget);
  });
}
