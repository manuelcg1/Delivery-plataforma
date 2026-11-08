import 'package:delivery_customer/app/theme/app_theme.dart';
import 'package:delivery_customer/core/providers.dart';
import 'package:delivery_customer/core/realtime/realtime_client.dart';
import 'package:delivery_customer/features/auth/data/auth_repository.dart';
import 'package:delivery_customer/features/auth/presentation/auth_controller.dart';
import 'package:delivery_customer/features/orders/data/commerce_repository.dart';
import 'package:delivery_customer/features/orders/presentation/commerce_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in [
    'PENDING',
    'IN_TRANSIT',
    'ARRIVED_AT_CUSTOMER',
    'DELIVERED',
    'CANCELLED'
  ]) {
    testWidgets('order detail preserves actions for $status', (tester) async {
      final repository = _Repository(status);
      final order = Order(
          id: 'order',
          number: 'ORD-123',
          status: status,
          total: 58,
          currency: 'PEN',
          createdAt: '2026-11-07T17:05:00Z',
          ratingSubmitted: false);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            commerceRepositoryProvider.overrideWithValue(repository),
            ordersProvider.overrideWith((ref) async => [order]),
            authControllerProvider.overrideWith(_SignedOut.new),
            customerRealtimeClientProvider.overrideWithValue(_Realtime()),
            realtimeClientProvider.overrideWithValue(_Realtime()),
          ],
          child: MaterialApp(
              theme: AppTheme.light(), home: OrderDetailPage(order: order))));
      await tester.pumpAndSettle();
      expect(find.text('ORD-123'), findsOneWidget);
      expect(find.text('PEN 58.00'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Chatear con el repartidor'),
          status == 'IN_TRANSIT' ? findsOneWidget : findsNothing);
      expect(
          find.text('Seguir pedido'),
          ['IN_TRANSIT', 'ARRIVED_AT_CUSTOMER'].contains(status)
              ? findsOneWidget
              : findsNothing);
      expect(find.text('Calificar pedido'),
          status == 'DELIVERED' ? findsOneWidget : findsNothing);
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

class _Repository implements CommerceRepository {
  _Repository(this.status);
  final String status;
  @override
  Future<Map<String, dynamic>> tracking(String id) async => {
        'deliveryId': 'delivery',
        'status': status,
        'courierName': 'Repartidor de prueba',
      };
  @override
  Future<List<DeliveryStatusEvent>> deliveryHistory(String id) async => const [
        DeliveryStatusEvent(
            id: 'event', status: 'PENDING', createdAt: '2026-11-07T17:05:00Z'),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Realtime implements RealtimeClient {
  @override
  Stream<RealtimeEvent> get events => const Stream.empty();
  @override
  void disconnect() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedOut extends AuthController {
  @override
  Future<SessionUser?> build() async => null;
}
