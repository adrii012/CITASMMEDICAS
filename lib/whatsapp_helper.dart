// lib/whatsapp_helper.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  /// Abre WhatsApp con mensaje prellenado.
  ///
  /// - Web: abre wa.me en pestaña nueva.
  /// - Android/iOS: intenta abrir WhatsApp app (whatsapp://). Si falla, usa wa.me y luego api.
  ///
  /// NOTA: WhatsApp NO permite enviar automático; solo abre el chat con el texto.
  static Future<bool> enviar({
    required String phone,
    required String message,
    String defaultCountryCode = '52', // MX por defecto
  }) async {
    final normalized = _normalizePhone(phone, defaultCountryCode: defaultCountryCode);
    if (normalized == null) return false;

    final text = Uri.encodeComponent(message);

    // ✅ links
    final waMe = Uri.parse('https://wa.me/$normalized?text=$text');
    final api = Uri.parse('https://api.whatsapp.com/send?phone=$normalized&text=$text');

    // ✅ deep link a la app
    final waApp = Uri.parse('whatsapp://send?phone=$normalized&text=$text');

    // ✅ Android intent (a veces ayuda si whatsapp:// falla)
    final waIntent = Uri.parse(
      'intent://send?phone=$normalized&text=$text#Intent;scheme=whatsapp;package=com.whatsapp;end',
    );

    // ---------------- WEB ----------------
    if (kIsWeb) {
      // En web, lo más estable es abrir un link https en nueva pestaña
      return await _launchSafe(waMe, mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank') ||
          await _launchSafe(api, mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
    }

    // ---------------- MOBILE ----------------
    // 1) Android: intenta intent:// primero (muy efectivo)
    if (Platform.isAndroid) {
      if (await _launchSafe(waIntent, mode: LaunchMode.externalApplication)) return true;
    }

    // 2) Intenta abrir la app WhatsApp
    if (await _launchSafe(waApp, mode: LaunchMode.externalApplication)) return true;

    // 3) Fallback a wa.me
    if (await _launchSafe(waMe, mode: LaunchMode.externalApplication)) return true;

    // 4) Fallback final
    return await _launchSafe(api, mode: LaunchMode.externalApplication);
  }

  /// Abre URL solo si el sistema dice que puede.
  static Future<bool> _launchSafe(
    Uri uri, {
    required LaunchMode mode,
    String? webOnlyWindowName,
  }) async {
    try {
      final can = await canLaunchUrl(uri);
      if (!can) return false;
      final ok = await launchUrl(uri, mode: mode, webOnlyWindowName: webOnlyWindowName);
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Normaliza a solo dígitos y agrega lada MX si es 10 dígitos.
  static String? _normalizePhone(
    String raw, {
    required String defaultCountryCode,
  }) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (digits.isEmpty) return null;

    // Quitar 00 internacional
    if (digits.startsWith('00')) digits = digits.substring(2);

    // México típico: 10 dígitos -> agregar 52
    if (digits.length == 10) digits = '$defaultCountryCode$digits';

    // Validación mínima
    if (digits.length < 11) return null;

    return digits;
  }
}