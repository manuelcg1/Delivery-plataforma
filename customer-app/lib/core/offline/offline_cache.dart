import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache {
  static Future<void> write(String key, Object value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(value));
  }

  static Future<dynamic> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(key);
    return value == null ? null : jsonDecode(value);
  }

  static Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
