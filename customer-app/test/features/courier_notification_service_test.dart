import 'package:delivery_customer/features/courier/notifications/courier_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification id is stable and delivery specific', () {
    final first = CourierNotificationService.notificationId('delivery-a');
    expect(first, CourierNotificationService.notificationId('delivery-a'));
    expect(
        first, isNot(CourierNotificationService.notificationId('delivery-b')));
    expect(first, greaterThanOrEqualTo(0));
  });

  test('los botones de la notificación se traducen al estado de la entrega',
      () {
    expect(courierOfferResponseStatus('ACCEPT'), 'ACCEPTED');
    expect(courierOfferResponseStatus('REJECT'), 'REJECTED');
    expect(courierOfferResponseStatus(null), isNull);
    expect(courierOfferDeliveryId('{"deliveryId":"d1"}'), 'd1');
    expect(courierOfferDeliveryId('no-json'), isNull);
    expect(courierOfferCategory, 'CERKA_NEW_DELIVERY');
  });
}
