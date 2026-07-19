import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_customer/core/config/app_config.dart';

void main() {
  test('uses safe Android emulator development defaults', () {
    final config = AppConfig.fromEnvironment();
    expect(config.environment, AppEnvironment.development);
    expect(config.apiBaseUrl, contains('10.0.2.2'));
  });
}
