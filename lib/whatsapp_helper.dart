import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  /// Abre WhatsApp con mensaje prellenado.
  /// phone puede venir: "8441234567", "+52 844 123 4567", "52-844-123-4567"
  static Future<bool> enviar({
    required String phone,
    required String message,
  }) async {
    final normalized = _normalizePhone(phone);
    if (normalized == null) return false;

    final encodedMsg = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$normalized?text=$encodedMsg');

    try {
      // webOnlyWindowName abre en pestaña nueva en Web
      // mode external abre WhatsApp / navegador externo cuando aplica
      return await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      return false;
    }
  }

  /// Normaliza a solo dígitos + mete 52 si parece México sin lada.
  static String? _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return null;

    // Si viene con 00 al inicio (00xx...), quitarlo
    if (digits.startsWith('00')) digits = digits.substring(2);

    // México típico: 10 dígitos -> agregar 52
    if (digits.length == 10) digits = '52$digits';

    // Validación ligera
    if (digits.length < 11) return null;

    return digits;
  }
}