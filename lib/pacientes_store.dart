import 'paciente.dart';

class PacientesStore {
  static final List<Paciente> pacientes = [];

  static Paciente? porId(String id) {
    for (final p in pacientes) {
      if (p.id == id) return p;
    }
    return null;
  }
}