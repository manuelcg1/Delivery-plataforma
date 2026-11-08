import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/core/providers.dart';
import 'package:delivery_customer/features/auth/presentation/auth_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, {bool small = false}) async {
    const store = SessionStore(FlutterSecureStorage());
    final api = ApiClient('https://example.test', store);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(requestOptions: options, data: {
        'pendingApproval': true,
        'message':
            'Tu cuenta de repartidor está pendiente de activación por el administrador.',
      }));
    }));
    if (small) {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
    }
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(small ? 1.5 : 1)),
                  child: child!,
                ),
            home: const AuthPage())));
    await tester.pumpAndSettle();
  }

  Future<void> register(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String hint, String text) async {
    final field = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == hint);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  testWidgets('login and register omit company and select exactly one profile',
      (tester) async {
    await open(tester);
    expect(find.textContaining('Código de empresa'), findsNothing);
    await register(tester);
    expect(find.textContaining('Código de empresa'), findsNothing);
    expect(find.text('Teléfono / WhatsApp'), findsWidgets);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cliente'))
            .selected,
        isTrue);
    await tester.ensureVisible(find.text('Repartidor'));
    await tester.tap(find.text('Repartidor'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cliente'))
            .selected,
        isFalse);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Repartidor'))
            .selected,
        isTrue);
  });

  testWidgets(
      'required phone validates and pending courier returns to login retaining email only',
      (tester) async {
    await open(tester);
    await register(tester);
    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(find.textContaining('válido de Perú'), findsOneWidget);
    await enter(tester, 'Nombre', 'Ana');
    await enter(tester, 'Apellido', 'Perez');
    await enter(tester, 'Teléfono / WhatsApp', '+51 (987) 654-321');
    await enter(tester, 'Correo electrónico', 'ana@example.com');
    await enter(tester, 'Ingresa tu contraseña', 'password123');
    await tester.ensureVisible(find.text('Repartidor'));
    await tester.tap(find.text('Repartidor'));
    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.textContaining('pendiente de activación'), findsOneWidget);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(
        fields.map((field) => field.controller!.text), ['ana@example.com', '']);
    const store = SessionStore(FlutterSecureStorage());
    expect(await store.accessToken(), isNull);
    expect(await store.refreshToken(), isNull);
  });

  testWidgets(
      'registration remains scrollable on small screen with keyboard and large text',
      (tester) async {
    await open(tester, small: true);
    await register(tester);
    await tester.ensureVisible(find.text('Registrarme'));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
