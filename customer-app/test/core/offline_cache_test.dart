import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_customer/core/offline/offline_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('stores and restores the last known payload', () async {
    SharedPreferences.setMockInitialValues({});
    await OfflineCache.write('tracking:order-1', {'status': 'IN_TRANSIT'});
    final value =
        await OfflineCache.read('tracking:order-1') as Map<String, dynamic>;
    expect(value['status'], 'IN_TRANSIT');
  });
}
