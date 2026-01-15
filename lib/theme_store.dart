import 'package:flutter/material.dart';

enum AppTheme {
  light,
  dark,
  medical,
}

class ThemeStore {
  static final ValueNotifier<AppTheme> theme =
      ValueNotifier(AppTheme.light);

  static void nextTheme() {
    switch (theme.value) {
      case AppTheme.light:
        theme.value = AppTheme.dark;
        break;
      case AppTheme.dark:
        theme.value = AppTheme.medical;
        break;
      case AppTheme.medical:
        theme.value = AppTheme.light;
        break;
    }
  }
}