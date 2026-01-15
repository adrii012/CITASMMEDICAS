class Notificaciones {
  static Future<void> inicializar() async {}
  static Future<void> programar({
    required String id,
    required String titulo,
    required String cuerpo,
    required DateTime fechaHora,
  }) async {}
  static Future<void> cancelar(String id) async {}
}