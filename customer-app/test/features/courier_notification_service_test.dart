import 'package:delivery_customer/features/courier/notifications/courier_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification id is stable and delivery specific', () {
    final first = CourierNotificationService.notificationId('delivery-a');
    expect(first, CourierNotificationService.notificationId('delivery-a'));
    expect(first, isNot(CourierNotificationService.notificationId('delivery-b')));
    expect(first, greaterThanOrEqualTo(0));
  });
}
