import 'package:delivery_customer/core/api/api_client.dart';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:delivery_customer/core/providers.dart';
import 'package:delivery_customer/features/address/domain/customer_address.dart';
import 'package:delivery_customer/features/address/presentation/customer_address_form_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crea una dirección y cierra sin usar un contexto desactivado',
      (tester) async {
    final api = ApiClient(
      'https://example.test',
      const SessionStore(FlutterSecureStorage()),
    );
    var createRequests = 0;
    final requests = <String>[];
    api.dio.interceptors.clear();
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add('${options.method} ${options.path}');
        if (options.path.endsWith('/address-search')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'suggestions': [
                {
                  'placeId': 'place-123',
                  'formattedText': 'Av. Los Álamos 13630, Perú',
                }
              ],
            },
          ));
          return;
        }
        if (options.path.contains('/address-place/')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'placeId': 'place-123',
              'formattedAddress': 'Av. Los Álamos 13630, Perú',
              'latitude': -12.0464,
              'longitude': -77.0428,
              'countryCode': 'PE',
            },
          ));
          return;
        }
        if (options.path.endsWith('/addresses') && options.method == 'POST') {
          createRequests++;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              ...(options.data as Map<String, dynamic>),
              'id': 'address-123',
            },
          ));
          return;
        }
        handler.reject(DioException(
          requestOptions: options,
          message: 'Solicitud inesperada: ${options.path}',
        ));
      },
    ));

    CustomerAddress? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<CustomerAddress>(
                  MaterialPageRoute(
                    builder: (_) => const CustomerAddressFormPage(),
                  ),
                );
              },
              child: const Text('Abrir formulario'),
            ),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'Av. Los Álamos 13630');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.tap(find.text('Av. Los Álamos 13630, Perú').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ubicación seleccionada'), findsOneWidget);

    await tester.ensureVisible(find.text('Nombre de quien recibe *'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de quien recibe *'),
      'Ingrid Luján',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Teléfono *'),
      '961350252',
    );
    expect(
      tester
          .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Nombre de quien recibe *'))
          .controller
          ?.text,
      'Ingrid Luján',
    );
    expect(
      tester
          .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Teléfono *'))
          .controller
          ?.text,
      '961350252',
    );
    tester.testTextInput.hide();
    await tester.pump();
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-address')),
    );
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.pump();
    expect(find.text('Revisa los campos marcados antes de continuar'),
        findsNothing);
    await tester.pumpAndSettle();

    expect(createRequests, 1, reason: requests.join(', '));
    expect(result?.label, 'Casa');
    expect(result?.formattedAddress, 'Av. Los Álamos 13630, Perú');
    expect(find.byType(CustomerAddressFormPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
