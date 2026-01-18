import 'paciente.dart';

class PacientesStore {
  /// Lista en memoria (se llena desde PersistenciaPacientes según clinicId)
  static final List<Paciente> pacientes = [];

  /// Buscar paciente por ID
  static Paciente? porId(String? id) {
    if (id == null || id.trim().isEmpty) return null;

    for (final p in pacientes) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// ¿Existe paciente por ID?
  static bool existe(String? id) {
    return porId(id) != null;
  }

  /// Total de pacientes
  static int total() => pacientes.length;

  /// Limpiar memoria (al cerrar sesión o cambiar de clínica)
  static void clear() {
    pacientes.clear();
  }
}