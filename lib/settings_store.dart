import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _kTheme = 'theme_mode_v1';
  static const _kAccent = 'accent_color_v1';
  static const _kBackground = 'background_color_v1';

  // ✅ Default: oscuro
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static final ValueNotifier<Color> accentColor =
      ValueNotifier<Color>(Colors.deepPurple);

  static final ValueNotifier<Color> backgroundColor =
      ValueNotifier<Color>(const Color(0xFF0B0F17)); // fondo oscuro suave

  static const List<Color> accentPalette = [
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.indigo,
    Colors.brown,
  ];

  static const List<Color> backgroundPalette = [
    Colors.white,
    Color(0xFFF4F6FA),
    Color(0xFFFFF7ED),
    Color(0xFFF0FFF4),
    Color(0xFFF5F3FF),
    Color(0xFFFFF1F2),
    Color(0xFFEFF6FF),
    Color(0xFF0B0F17),
    Color(0xFF111827),
    Color(0xFF000000),
  ];

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();

    // Tema
    final themeStr = prefs.getString(_kTheme);
    if (themeStr != null) {
      themeMode.value = switch (themeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } else {
      themeMode.value = ThemeMode.dark; // default real
    }

    // Acento
    final accentInt = prefs.getInt(_kAccent);
    if (accentInt != null) accentColor.value = Color(accentInt);

    // Fondo
    final bgInt = prefs.getInt(_kBackground);
    if (bgInt != null) backgroundColor.value = Color(bgInt);
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();

    final v = (mode == ThemeMode.dark)
        ? 'dark'
        : (mode == ThemeMode.light)
            ? 'light'
            : 'system';

    await prefs.setString(_kTheme, v);
  }

  static Future<void> setAccent(Color color) async {
    accentColor.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccent, color.value);
  }

  static Future<void> setBackground(Color color) async {
    backgroundColor.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBackground, color.value);
  }
}