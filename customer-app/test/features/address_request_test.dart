import 'package:delivery_customer/features/home/data/customer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the create and update address payload consistently', () {
    final payload = addressRequestData(
      label: ' Casa ',
      recipientName: ' Cliente ',
      phone: ' 999999999 ',
      addressLine: ' Calle 1 ',
      district: ' Lima ',
      isDefault: true,
    );

    expect(payload['label'], 'Casa');
    expect(payload['recipientName'], 'Cliente');
    expect(payload['phone'], '999999999');
    expect(payload['addressLine'], 'Calle 1');
    expect(payload['district'], 'Lima');
    expect(payload['countryCode'], 'PE');
    expect(payload['isDefault'], isTrue);
  });
}
