// lib/admin_pin_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class AdminPinStore {
  static const String _kPinKey = 'admin_pin';

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_kPinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinKey, pin);
  }

  static Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPinKey);
    if (saved == null) return false;
    return saved == pin;
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPinKey);
  }
}