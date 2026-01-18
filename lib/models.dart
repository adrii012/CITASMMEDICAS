class Paciente {
  final String id;
  String nombre;
  int edad;
  String telefono;
  String notas;

  Paciente({
    required this.id,
    required this.nombre,
    this.edad = 0,
    this.telefono = '',
    this.notas = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'edad': edad,
        'telefono': telefono,
        'notas': notas,
      };

  static Paciente fromJson(Map<String, dynamic> json) => Paciente(
        id: json['id']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        edad: (json['edad'] is int)
            ? json['edad']
            : int.tryParse(json['edad']?.toString() ?? '0') ?? 0,
        telefono: json['telefono']?.toString() ?? '',
        notas: json['notas']?.toString() ?? '',
      );
}

class Cita {
  final String id;
  final String pacienteId;
  DateTime fecha;
  String motivo;
  String estado; // pendiente / completada / cancelada

  Cita({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    this.motivo = '',
    this.estado = 'pendiente',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pacienteId': pacienteId,
        'fecha': fecha.toIso8601String(),
        'motivo': motivo,
        'estado': estado,
      };

  static Cita fromJson(Map<String, dynamic> json) => Cita(
        id: json['id']?.toString() ?? '',
        pacienteId: json['pacienteId']?.toString() ?? '',
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
            DateTime.now(),
        motivo: json['motivo']?.toString() ?? '',
        estado: json['estado']?.toString() ?? 'pendiente',
      );
}