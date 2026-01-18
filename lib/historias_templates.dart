// lib/historias_templates.dart
import 'historia_clinica.dart';

class HistoriasTemplates {
  static Map<String, String> base() => {
    'fichaIdentificacion': '',
    'ahf': '',
    'app': '',
    'apnp': '',
    'padecimientoActual': '',
    'interrogatorioSistemas': '',
    'exploracionFisica': '',
    'impresionDx': '',
    'plan': '',
    'notas': '',
  };

  static Map<String, String> gine() => {
    ...base(),
    'ginecoObstetricos': '',
    'fum': '',
    'gestasPartosAbortosCesareas': '',
    'metodoAnticonceptivo': '',
  };

  static Map<String, String> trauma() => {
    ...base(),
    'mecanismoLesion': '',
    'zonaAfectada': '',
    'escalaDolor': '',
    'neurovascular': '',
    'imagenologia': '',
  };

  static Map<String, String> urgencias() => {
    ...base(),
    'motivoConsultaUrg': '',
    'triage': '',
    'signosVitales': '',
    'alergias': '',
    'medsActuales': '',
    'riesgo': '',
    'manejoInicial': '',
  };

  static Map<String, String> forTipo(HistoriaTipo tipo) {
    return switch (tipo) {
      HistoriaTipo.general => base(),
      HistoriaTipo.gine => gine(),
      HistoriaTipo.trauma => trauma(),
      HistoriaTipo.urgencias => urgencias(),
    };
  }
}