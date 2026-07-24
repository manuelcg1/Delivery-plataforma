import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_customer/features/auth/data/auth_repository.dart';

void main() {
  test('identifies a courier session from backend roles', () {
    final user = SessionUser.fromJson({
      'id': 'user-1',
      'firstName': 'Maria',
      'tenant': {'id': 'tenant-1', 'code': 'elite'},
      'roles': ['COURIER'],
    });

    expect(user.isCourier, isTrue);
    expect(user.roles, contains('COURIER'));
  });

  test('keeps customer sessions in the customer experience', () {
    final user = SessionUser.fromJson({
      'id': 'user-2',
      'firstName': 'Ana',
      'tenant': {'id': 'tenant-1', 'code': 'elite'},
      'roles': ['CUSTOMER'],
    });

    expect(user.isCourier, isFalse);
  });
}
