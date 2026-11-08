import 'package:delivery_customer/features/customer_tracking/notifications/arrival_notice_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const arrival = <String, dynamic>{
    'type': 'COURIER_ARRIVED',
    'deliveryId': 'delivery-1',
    'orderId': 'order-1',
    'eventId': 'COURIER_ARRIVED:delivery-1',
  };

  test('push and websocket arrival show only one notice', () async {
    final shown = <String>[];
    final coordinator = ArrivalNoticeCoordinator(scope: 'tenant:customer');
    coordinator.onNotice = (orderId) async => shown.add(orderId);
    await Future.wait(
        [coordinator.receive(arrival), coordinator.receive(arrival)]);
    expect(shown, ['order-1']);
    await coordinator.receive(arrival);
    expect(shown, ['order-1']);
  });

  test('visible tracking receives inline notice instead of general notice',
      () async {
    final shown = <String>[];
    final coordinator = ArrivalNoticeCoordinator(scope: 'tenant:customer');
    coordinator.onNotice = (_) async => shown.add('general');
    coordinator.watchTracking('order-1',
        isVisible: () => true, show: () async => shown.add('tracking'));
    await coordinator.receive(arrival);
    expect(shown, ['tracking']);
  });

  test('covered tracking page does not suppress general notice', () async {
    final shown = <String>[];
    final coordinator = ArrivalNoticeCoordinator(scope: 'tenant:customer');
    coordinator.onNotice = (_) async => shown.add('general');
    coordinator.watchTracking('order-1',
        isVisible: () => false, show: () async => shown.add('tracking'));
    await coordinator.receive(arrival);
    expect(shown, ['general']);
  });

  test('dedup survives recreation and is isolated by account', () async {
    var count = 0;
    for (final scope in [
      'tenant:customer',
      'tenant:customer',
      'tenant:another'
    ]) {
      final coordinator = ArrivalNoticeCoordinator(scope: scope);
      coordinator.onNotice = (_) async => count++;
      await coordinator.receive(arrival);
    }
    expect(count, 2);
  });

  test('malformed and assignment payloads do not become customer arrivals',
      () async {
    var count = 0;
    final coordinator = ArrivalNoticeCoordinator(scope: 'tenant:customer');
    coordinator.onNotice = (_) async => count++;
    await coordinator.receive({'type': 'COURIER_ARRIVED', 'deliveryId': 'd'});
    await coordinator.receive({...arrival, 'type': 'NEW_DELIVERY_ASSIGNMENT'});
    expect(count, 0);
  });

  test('failed presentation remains eligible for retry', () async {
    var attempts = 0;
    final coordinator = ArrivalNoticeCoordinator(scope: 'tenant:customer');
    coordinator.onNotice = (_) async {
      attempts++;
      if (attempts == 1) throw StateError('not ready');
    };
    await expectLater(coordinator.receive(arrival), throwsStateError);
    await coordinator.receive(arrival);
    expect(attempts, 2);
  });
}
