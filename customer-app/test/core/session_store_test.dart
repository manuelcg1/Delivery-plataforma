import 'dart:convert';
import 'package:delivery_customer/core/auth/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

String tokenWithExpiration(DateTime expiration) {
  String part(Map<String,Object> value)=>base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=','');
  return '${part({'alg':'none'})}.${part({'exp':expiration.millisecondsSinceEpoch~/1000})}.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>FlutterSecureStorage.setMockInitialValues({}));

  test('valid access token does not require refresh',() async {
    const store=SessionStore(FlutterSecureStorage());
    await store.save(accessToken:tokenWithExpiration(DateTime.now().toUtc().add(const Duration(minutes:10))),refreshToken:'refresh');
    expect(await store.needsRefresh(),isFalse);
  });

  test('expired and near-expiration access tokens require refresh',() async {
    const store=SessionStore(FlutterSecureStorage());
    await store.save(accessToken:tokenWithExpiration(DateTime.now().toUtc().add(const Duration(seconds:30))),refreshToken:'refresh');
    expect(await store.needsRefresh(),isTrue);
  });
}
