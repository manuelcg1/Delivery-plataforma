import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:delivery_customer/features/orders/data/yape_checkout.dart';
import 'package:delivery_customer/features/orders/presentation/yape_checkout_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const settings = YapeSettings(
      enabled: true,
      phone: '999888777',
      holderName: 'Ana',
      qrUrl: 'https://example.com/qr',
      version: '1');
  testWidgets('failed QR blocks declaration and offers retry', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: YapeCheckoutSheet(load: () async => settings, total: 25))));
    await tester.pumpAndSettle();
    expect(find.text('999888777'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('S/ 25.00'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.text('No pudimos cargar el QR. Intenta nuevamente.'),
        findsOneWidget);
  });
  testWidgets(
      'real decoded QR enables declaration and resume requires a fresh QR',
      (tester) async {
    final client = QrHttpClient();
    debugNetworkImageHttpClientProvider = () => client;
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
    });
    var loads = 0;
    YapeSettings? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<YapeSettings>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => YapeCheckoutSheet(
                              load: () async {
                                loads++;
                                return YapeSettings(
                                    enabled: true,
                                    phone: '999888777',
                                    holderName: 'Ana',
                                    qrUrl: 'https://example.com/qr-$loads',
                                    version: 'v$loads');
                              },
                              total: 25));
                    },
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    Object? imageError;
    await tester.runAsync(() => precacheImage(
          const NetworkImage('https://example.com/qr-1'),
          tester.element(find.byType(YapeCheckoutSheet)),
          onError: (error, _) => imageError = error,
        ));
    expect(imageError, isNull);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(loads, 2);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    client.secondFrame.complete(qrPng);
    await tester.runAsync(() => precacheImage(
          const NetworkImage('https://example.com/qr-2'),
          tester.element(find.byType(YapeCheckoutSheet)),
          onError: (error, _) => imageError = error,
        ));
    expect(imageError, isNull);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(result?.version, 'v2');
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
  });
  testWidgets('missing configuration blocks declaration', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: YapeCheckoutSheet(
                load: () async => const YapeSettings(enabled: false),
                total: 25))));
    await tester.pumpAndSettle();
    expect(find.text('Yape no está disponible para este comercio.'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}

final qrPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

class QrHttpClient implements HttpClient {
  final secondFrame = Completer<List<int>>();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => QrHttpRequest(
      url.path.endsWith('2') ? secondFrame.future : Future.value(qrPng));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class QrHttpRequest implements HttpClientRequest {
  QrHttpRequest(this.bytes);
  final Future<List<int>> bytes;
  @override
  final HttpHeaders headers = QrHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => QrHttpResponse(await bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class QrHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class QrHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  QrHttpResponse(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
