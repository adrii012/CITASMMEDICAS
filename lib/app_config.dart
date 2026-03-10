// lib/app_config.dart
import 'package:flutter/foundation.dart';

class AppConfig {
  static const String remoteLicenseUrl = kIsWeb
      ? '' // ✅ En Web no se usa (evita CORS)
      : 'https://raw.githubusercontent.com/doctorhouseadrian1/Citas-licenses/main/license.json';
}