import 'package:delivery_customer/features/auth/data/auth_repository.dart';
import 'package:delivery_customer/features/auth/presentation/auth_controller.dart';
import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:delivery_customer/features/home/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedOut extends AuthController {
  @override
  Future<SessionUser?> build() async => null;
}

Merchant merchant(String name, String? type) => Merchant.fromJson({
      'id': name,
      'code': name,
      'name': name,
      'description': 'Descripción interna',
      'branchId': 'branch-$name',
      'branchName': 'Sucursal $name',
      'currency': 'PEN',
      if (type != null) 'merchantType': type,
    });

Future<void> showHome(WidgetTester tester,
    {double width = 390,
    double textScale = 1,
    List<Merchant> Function()? merchantItems}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_SignedOut.new),
      addressesProvider.overrideWith((ref) async => []),
      merchantsProvider.overrideWith((ref) async =>
          merchantItems?.call() ??
          [
            merchant('HELADOS', 'ICE_CREAM'),
            merchant('Cafe', 'RESTAURANT'),
            merchant('Antiguo', null),
          ]),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: HomePage()),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> selectCategory(WidgetTester tester, String code) async {
  final tile = find.byKey(ValueKey('category-$code'));
  final carousel = find.byKey(const ValueKey('merchant-category-carousel'));
  for (var attempt = 0;
      attempt < 30 && tile.hitTestable().evaluate().isEmpty;
      attempt++) {
    await tester.drag(carousel, const Offset(-120, 0));
    await tester.pumpAndSettle();
  }
  expect(tile.hitTestable(), findsOneWidget);
  await tester.tap(tile.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('filters in place and clears without showing branch names',
      (tester) async {
    await showHome(tester);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.textContaining('Sucursal'), findsNothing);
    await selectCategory(tester, 'ICE_CREAM');
    expect(find.text('HELADOS'), findsOneWidget);
    expect(find.text('Cafe'), findsNothing);
    expect(find.text('Antiguo'), findsNothing);
    expect(find.text('Heladería · 1 comercio'), findsOneWidget);
    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('Antiguo'), findsOneWidget);
    expect(find.text('Ver todos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty category can recover with Todos on a narrow screen',
      (tester) async {
    await showHome(tester, width: 320);
    await selectCategory(tester, 'PHARMACY');
    expect(find.text('No hay comercios disponibles en esta categoría.'),
        findsOneWidget);
    expect(find.text('Cafe'), findsNothing);
    final carousel = find.byKey(const ValueKey('merchant-category-carousel'));
    await tester.drag(carousel, const Offset(2200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-ALL')));
    await tester.pumpAndSettle();
    expect(find.text('Cafe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps selection and recomputes results after refresh',
      (tester) async {
    var items = [
      merchant('HELADOS', 'ICE_CREAM'),
      merchant('Cafe', 'RESTAURANT')
    ];
    await showHome(tester, merchantItems: () => items);
    await selectCategory(tester, 'ICE_CREAM');
    items = [
      merchant('Nuevo helado', 'ICE_CREAM'),
      merchant('Cafe', 'RESTAURANT')
    ];
    ProviderScope.containerOf(tester.element(find.byType(HomePage)))
        .invalidate(merchantsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Nuevo helado'), findsOneWidget);
    expect(find.text('HELADOS'), findsNothing);
    expect(find.text('Cafe'), findsNothing);
    expect(find.text('Heladería · 1 comercio'), findsOneWidget);
  });

  testWidgets(
      'supports large text and preserves unknown merchant types in Otros',
      (tester) async {
    await showHome(tester,
        width: 320,
        textScale: 1.5,
        merchantItems: () => [merchant('Sin clasificar', 'FUTURE_TYPE')]);
    await selectCategory(tester, 'OTHER');
    expect(find.text('Sin clasificar'), findsOneWidget);
    expect(find.text('Otros · 1 comercio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
