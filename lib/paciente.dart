class Paciente {
  String id;
  String nombre;
  String telefono;
  String notas;

  /// ✅ NUEVO: para estadísticas “pacientes nuevos por mes”
  /// ISO string: 2026-01-12T10:30:00.000
  String createdAtIso;

  Paciente({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.notas = '',
    String? createdAtIso,
  }) : createdAtIso = createdAtIso ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'telefono': telefono,
        'notas': notas,
        'createdAtIso': createdAtIso,
      };

  factory Paciente.fromJson(Map<String, dynamic> json) => Paciente(
        id: (json['id'] ?? '').toString(),
        nombre: (json['nombre'] ?? '').toString(),
        telefono: (json['telefono'] ?? '').toString(),
        notas: (json['notas'] ?? '').toString(),
        createdAtIso: (json['createdAtIso'] ?? '').toString().trim().isEmpty
            ? DateTime.now().toIso8601String()
            : (json['createdAtIso'] ?? '').toString(),
      );
}