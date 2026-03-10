// lib/historias_templates.dart
import 'historia_clinica.dart';

class HistoriasTemplates {
  static Map<String, String> base() => {
        'horaEntrada': '',
        'horaSalida': '',

        'fichaIdentificacion': '',
        'ahf': '',
        'app': '',
        'apnp': '',
        'alergias': '',
        'medicamentos': '',
        'padecimientoActual': '',
        'interrogatorioSistemas': '',
        'signosVitales': '',
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
        'riesgo': '',
        'manejoInicial': '',
        'procedimientos': '',
        'respuestaTratamiento': '',
        'disposicion': '',
      };

  /// ✅ NUEVO: ODONTOLOGÍA
  static Map<String, String> odontologia() => {
        ...base(),

        // datos dentales
        'motivoConsulta': '',
        'dolorEVA': '',
        'pieza': '',
        'diagnosticoDental': '',
        'odontograma': '',
        'tejidosBlandos': '',
        'encias': '',
        'atm': '',
        'oclusion': '',

        // procedimientos / plan
        'procedimientoRealizado': '',
        'materiales': '',
        'anestesia': '',
        'indicacionesPost': '',
        'receta': '',
        'proximaCita': '',
      };

  static Map<String, String> forTipo(HistoriaTipo tipo) {
    return switch (tipo) {
      HistoriaTipo.general => base(),
      HistoriaTipo.gine => gine(),
      HistoriaTipo.trauma => trauma(),
      HistoriaTipo.urgencias => urgencias(),
      HistoriaTipo.odontologia => odontologia(),
    };
  }
}