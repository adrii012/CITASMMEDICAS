// lib/citas_store.dart

class CitasStore {
  static final List<Cita> citas = [];

  static List<Cita> get citasOrdenadas {
    final list = List<Cita>.from(citas);
    list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return list;
  }

  static void eliminar(String id) {
    citas.removeWhere((c) => c.id == id);
  }

  static void setEstado(String id, EstadoCita estado) {
    final idx = citas.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    citas[idx].estado = estado;
  }

  static void marcarEntrada(String id) {
    final idx = citas.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    citas[idx].entradaIso = DateTime.now().toIso8601String();
  }

  static void marcarSalida(String id) {
    final idx = citas.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    citas[idx].salidaIso = DateTime.now().toIso8601String();
  }

  static void limpiarEntrada(String id) {
    final idx = citas.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    citas[idx].entradaIso = '';
  }

  static void limpiarSalida(String id) {
    final idx = citas.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    citas[idx].salidaIso = '';
  }
}

enum EstadoCita { pendiente, realizada, cancelada }

class Cita {
  String id;
  String paciente;
  String? pacienteId;

  DateTime fechaHora;
  EstadoCita estado;
  String notas;

  int duracionMin;

  // ✅ NUEVO ODONTO (no rompe nada si no se usa)
  String service;   // ej: Limpieza, Endodoncia, Resina...
  String motivo;    // ej: Dolor, Revisión, Limpieza...
  String pieza;     // ej: 36, 11, 2.6
  String phone;     // teléfono guardado en la cita (para WhatsApp)

  String entradaIso;
  String salidaIso;

  Cita({
    required this.id,
    required this.paciente,
    required this.fechaHora,
    required this.estado,
    required this.notas,
    this.pacienteId,
    this.duracionMin = 30,

    // ✅ NUEVOS (defaults)
    this.service = '',
    this.motivo = '',
    this.pieza = '',
    this.phone = '',

    this.entradaIso = '',
    this.salidaIso = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'paciente': paciente,
        'pacienteId': pacienteId,
        'fechaHora': fechaHora.toIso8601String(),
        'estado': estado.name,
        'notas': notas,
        'duracionMin': duracionMin,
        'service': service,
        'motivo': motivo,
        'pieza': pieza,
        'phone': phone,
        'entradaIso': entradaIso,
        'salidaIso': salidaIso,
      };

  static Cita fromJson(Map<String, dynamic> json) {
    final estadoStr = (json['estado'] ?? 'pendiente').toString();
    final estado = EstadoCita.values.firstWhere(
      (e) => e.name == estadoStr,
      orElse: () => EstadoCita.pendiente,
    );

    final dur = json['duracionMin'];
    final duracion = (dur is int) ? dur : int.tryParse((dur ?? '30').toString()) ?? 30;

    return Cita(
      id: (json['id'] ?? '').toString(),
      paciente: (json['paciente'] ?? '').toString(),
      pacienteId: json['pacienteId']?.toString(),
      fechaHora: DateTime.parse(
        (json['fechaHora'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      estado: estado,
      notas: (json['notas'] ?? '').toString(),
      duracionMin: duracion,

      // ✅ NUEVOS
      service: (json['service'] ?? '').toString(),
      motivo: (json['motivo'] ?? '').toString(),
      pieza: (json['pieza'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),

      entradaIso: (json['entradaIso'] ?? '').toString(),
      salidaIso: (json['salidaIso'] ?? '').toString(),
    );
  }
}