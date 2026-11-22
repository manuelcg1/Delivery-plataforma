import 'package:delivery_customer/features/chat/presentation/delivery_chat_page.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el chat solo está abierto con la entrega en curso', () {
    expect(isDeliveryChatOpen('IN_TRANSIT'), isTrue);
    expect(isDeliveryChatOpen('ARRIVED_AT_CUSTOMER'), isTrue);
    expect(isDeliveryChatOpen('ACCEPTED'), isFalse);
    expect(isDeliveryChatOpen('PICKED_UP'), isFalse);
    expect(isDeliveryChatOpen('ASSIGNED'), isFalse);
    expect(isDeliveryChatOpen('DELIVERED'), isFalse);
  });

  testWidgets('el repartidor ve y envía mensajes', (tester) async {
    final messages = <ChatMessage>[
      const ChatMessage(
          id: '1',
          deliveryId: 'd',
          senderType: 'CUSTOMER',
          message: 'Toca el timbre',
          createdAt: '2026-11-21T10:00:00Z'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: DeliveryChatPage(
        title: 'Chat con el cliente',
        viewerType: 'COURIER',
        refreshInterval: const Duration(hours: 1),
        load: () async => List.of(messages),
        send: (text) async => messages.add(ChatMessage(
            id: '2',
            deliveryId: 'd',
            senderType: 'COURIER',
            message: text,
            createdAt: '2026-11-21T10:01:00Z')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Toca el timbre'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat-input')), 'Ya llegué');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Ya llegué'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('el contador muestra 9+ desde 10 mensajes', () {
    expect(unreadBadgeLabel(1), '1');
    expect(unreadBadgeLabel(9), '9');
    expect(unreadBadgeLabel(12), '9+');
  });

  test('solo cuentan los mensajes de la otra persona sin leer', () {
    const mine = ChatMessage(
        id: '1',
        deliveryId: 'd',
        senderType: 'COURIER',
        message: 'hola',
        createdAt: '2026-11-22T10:00:00Z');
    const theirs = ChatMessage(
        id: '2',
        deliveryId: 'd',
        senderType: 'CUSTOMER',
        message: 'hola',
        createdAt: '2026-11-22T10:01:00Z');
    expect(mine.unreadFor('COURIER'), isFalse);
    expect(theirs.unreadFor('COURIER'), isTrue);
    expect(theirs.unreadFor('CUSTOMER'), isFalse);
  });

  testWidgets('el aviso no cambia el tamaño del botón', (tester) async {
    Future<Size> sizeWith(int unread) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatButtonWithBadge(
                key: const Key('chat'), onPressed: () {}, unread: unread),
          ),
        ),
      ));
      return tester.getSize(find.byKey(const Key('chat')));
    }

    final plain = await sizeWith(0);
    expect(find.byKey(const Key('chat-unread-badge')), findsNothing);
    final withBadge = await sizeWith(3);
    expect(find.text('3'), findsOneWidget);
    expect(withBadge, plain);
  });

  testWidgets('al abrir marca como leído y separa los mensajes nuevos',
      (tester) async {
    var marked = 0;
    await tester.pumpWidget(MaterialApp(
      home: DeliveryChatPage(
        title: 'Chat con el cliente',
        viewerType: 'COURIER',
        refreshInterval: const Duration(hours: 1),
        markRead: () async => marked++,
        load: () async => const [
          ChatMessage(
              id: 'old',
              deliveryId: 'd',
              senderType: 'CUSTOMER',
              message: 'Toca el timbre',
              createdAt: '2026-11-22T10:00:00Z',
              readAt: '2026-11-22T10:00:05Z'),
          ChatMessage(
              id: 'new',
              deliveryId: 'd',
              senderType: 'CUSTOMER',
              message: 'Ya bajo',
              createdAt: '2026-11-22T10:02:00Z'),
        ],
        send: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-new-divider')), findsOneWidget);
    expect(marked, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
