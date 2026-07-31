import 'package:delivery_customer/features/courier/tracking/domain/tracking_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const states = {
    'PENDING',
    'SEARCHING_COURIER',
    'ASSIGNED',
    'ACCEPTED',
    'ARRIVED_AT_MERCHANT',
    'PICKED_UP',
    'IN_TRANSIT',
    'ARRIVED_AT_CUSTOMER',
    'DELIVERED',
    'FAILED',
    'CANCELLED',
    'REJECTED',
    'EXPIRED',
  };

  test('only PICKED_UP starts tracking', () {
    for (final state in states) {
      expect(shouldStartTracking(state), state == 'PICKED_UP', reason: state);
    }
  });

  test('tracking continues only through the delivery journey', () {
    for (final state in states) {
      expect(
        shouldContinueTracking(state),
        const {'PICKED_UP', 'IN_TRANSIT', 'ARRIVED_AT_CUSTOMER'}
            .contains(state),
        reason: state,
      );
    }
  });

  test('all terminal states stop tracking', () {
    for (final state in states) {
      expect(
        shouldStopTracking(state),
        const {'DELIVERED', 'FAILED', 'CANCELLED', 'REJECTED', 'EXPIRED'}
            .contains(state),
        reason: state,
      );
    }
  });
}
