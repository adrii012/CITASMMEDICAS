// lib/historias_store.dart
import 'historia_clinica.dart';

class HistoriasStore {
  static final List<HistoriaClinica> historias = [];

  // ✅ labels para UI
  static const Map<HistoriaTipo, String> tipos = {
    HistoriaTipo.general: 'Clínica General',
    HistoriaTipo.gine: 'Ginecología',
    HistoriaTipo.trauma: 'Trauma / Ortopedia',
    HistoriaTipo.urgencias: 'Urgencias',
  };

  static List<HistoriaClinica> porPaciente(String pacienteId) {
    final list = historias.where((h) => h.pacienteId == pacienteId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // nueva primero
    return list;
  }

  static HistoriaClinica? porId(String id) {
    for (final h in historias) {
      if (h.id == id) return h;
    }
    return null;
  }

  static void upsert(HistoriaClinica h) {
    final idx = historias.indexWhere((x) => x.id == h.id);
    if (idx >= 0) {
      historias[idx] = h;
    } else {
      historias.add(h);
    }
  }

  static void eliminar(String id) {
    historias.removeWhere((x) => x.id == id);
  }

  static void clear() {
    historias.clear();
  }
}