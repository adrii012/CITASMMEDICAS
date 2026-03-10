// lib/historia_clinica.dart
enum HistoriaTipo { general, gine, trauma, urgencias, odontologia }

class HistoriaClinica {
  String id;
  String pacienteId;
  DateTime createdAt;
  HistoriaTipo tipo;

  /// Secciones tipo: "padecimientoActual" -> "texto..."
  Map<String, String> secciones;

  HistoriaClinica({
    required this.id,
    required this.pacienteId,
    required this.createdAt,
    required this.tipo,
    required this.secciones,
  });

  /// ✅ Helpers: hora entrada/salida dentro del mapa
  String get horaEntrada => secciones['horaEntrada'] ?? '';
  String get horaSalida => secciones['horaSalida'] ?? '';

  set horaEntrada(String v) => secciones['horaEntrada'] = v.trim();
  set horaSalida(String v) => secciones['horaSalida'] = v.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'pacienteId': pacienteId,
        'createdAt': createdAt.toIso8601String(),
        'tipo': tipo.name,
        'secciones': secciones,
      };

  static HistoriaClinica fromJson(Map<String, dynamic> j) {
    final tipoStr = (j['tipo'] ?? 'general').toString();
    final tipo = HistoriaTipo.values.firstWhere(
      (e) => e.name == tipoStr,
      orElse: () => HistoriaTipo.general,
    );

    final rawSec = j['secciones'];
    final secs = <String, String>{};
    if (rawSec is Map) {
      rawSec.forEach((k, v) => secs[k.toString()] = (v ?? '').toString());
    }

    // ✅ asegurar llaves básicas para que no truene UI
    secs.putIfAbsent('horaEntrada', () => '');
    secs.putIfAbsent('horaSalida', () => '');

    return HistoriaClinica(
      id: (j['id'] ?? '').toString(),
      pacienteId: (j['pacienteId'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      tipo: tipo,
      secciones: secs,
    );
  }

  /// ✅ Plantillas completas por "especialidad" (tipo)
  /// Nota: tu UI mostrará automáticamente todas las llaves.
  static Map<String, String> plantilla(HistoriaTipo tipo) {
    // =========================
    // BASE (común para todos)
    // =========================
    final base = <String, String>{
      // tiempos
      'horaEntrada': '',
      'horaSalida': '',

      // identificación / contexto (rápido)
      'motivoConsulta': '',
      'padecimientoActual': '',

      // antecedentes base
      'app': '', // antecedentes personales patológicos
      'apnp': '', // no patológicos
      'alergias': '',
      'medicamentos': '',
      'quirurgicos': '',
      'hospitalizaciones': '',
      'transfusiones': '',
      'toxicomanias': '',
      'heredofamiliares': '',

      // revisión por sistemas (resumen)
      'revisionSistemas': '',

      // exploración y signos
      'signosVitales': '', // TA/FC/FR/T/SpO2
      'exploracionFisica': '',

      // diagn / plan
      'impresionDiagnostica': '',
      'dxDiferenciales': '',
      'plan': '',
      'estudiosSolicitados': '',
      'tratamiento': '',
      'indicaciones': '',
      'pronostico': '',

      // evolución / notas
      'notaEvolucion': '',
      'notas': '',
    };

    // =========================
    // PLANTILLAS POR TIPO
    // =========================
    switch (tipo) {
      case HistoriaTipo.general:
        base.addAll({
          // interrogatorio dirigido
          'inicioEvolucion': '',
          'localizacion': '',
          'intensidad': '',
          'caracteristicas': '',
          'factoresAgravantes': '',
          'factoresAtenuantes': '',
          'sintomasAsociados': '',
          'tratPrevio': '',

          // preventivo (útil en consulta general)
          'vacunacion': '',
          'tamizajes': '', // PAP, mamografía, etc.
          'estiloVida': '', // dieta/ejercicio/sueño
          'riesgos': '', // ocupacionales, etc.

          // cierre
          'planSeguimiento': '',
        });
        break;

      case HistoriaTipo.gine:
        base.addAll({
          'g': '',
          'p': '',
          'c': '',
          'a': '',
          'e': '',
          'fUM': '',
          'fPP': '',
          'edadMenarca': '',
          'cicloMenstrual': '',
          'dismenorrea': '',
          'irs': '',
          'parejasSexuales': '',
          'metodoAnticonceptivo': '',
          'its': '',
          'papanicolaou': '',
          'mastografia': '',
          'vidaSexual': '',
          'sangrado': '',
          'flujo': '',
          'dolorPelvico': '',
          'dispareunia': '',
          'embarazoActual': '',
          'movimientosFetales': '',
          'contracciones': '',
          'perdidaLiquido': '',
          'signosAlarma': '',
          'exploracionGine': '',
          'especuloscopia': '',
          'tactoBimanual': '',
          'fondoUterino': '',
          'fcf': '',
          'bh': '',
          'ego': '',
          'pruebaEmbarazo': '',
          'usg': '',
        });
        break;

      case HistoriaTipo.trauma:
        base.addAll({
          'mecanismoLesion': '',
          'tiempoEvolucion': '',
          'sitioLesion': '',
          'dominancia': '',
          'dolorEVA': '',
          'limitacionFuncional': '',
          'deformidad': '',
          'edemaEquimosis': '',
          'heridas': '',
          'sangradoActivo': '',
          'neurovascular': '',
          'pulsosDistales': '',
          'llenadoCapilar': '',
          'sensibilidad': '',
          'fuerza': '',
          'movilidad': '',
          'compartimental': '',
          'inspeccion': '',
          'palpacion': '',
          'rangoMov': '',
          'pruebasEspeciales': '',
          'rxLabs': '',
          'rx': '',
          'tac': '',
          'usg': '',
          'rm': '',
          'analgesia': '',
          'reduccion': '',
          'inmovilizacion': '',
          'férulaYeso': '',
          'curacion': '',
          'profilaxisTetanos': '',
          'antibiotico': '',
          'interconsulta': '',
          'referencia': '',
          'incapacidad': '',
          'rehabilitacion': '',
        });
        break;

      case HistoriaTipo.urgencias:
        base.addAll({
          'triage': '',
          'prioridad': '',
          'aViaAerea': '',
          'bRespiracion': '',
          'cCirculacion': '',
          'dNeurologico': '',
          'eExposicion': '',
          'glasgow': '',
          'pupilas': '',
          'deficitFocal': '',
          'convulsiones': '',
          'dolorToracico': '',
          'disnea': '',
          'tos': '',
          'sibilancias': '',
          'estertores': '',
          'edema': '',
          'perfusión': '',
          'dolorAbdominal': '',
          'vomito': '',
          'diarrea': '',
          'diuresis': '',
          'ultimoAlimento': '',
          'eventosPrevios': '',
          'riesgoTrombotico': '',
          'intervenciones': '',
          'liquidosIV': '',
          'oxigeno': '',
          'medsAdministrados': '',
          'procedimientos': '',
          'estudiosUrgencias': '',
          'ekg': '',
          'gases': '',
          'labs': '',
          'imagen': '',
          'respuestaTratamiento': '',
          'disposicion': '',
          'criteriosAlta': '',
          'signosAlarma': '',
        });
        break;

      case HistoriaTipo.odontologia:
        // ✅ ODONTOLOGÍA (plantilla)
        base.addAll({
          'motivoConsultaDental': '',
          'dolorEVA': '',
          'pieza': '',

          'diagnosticoDental': '',
          'odontograma': '',

          'tejidosBlandos': '',
          'encias': '',
          'atm': '',
          'oclusion': '',

          'procedimientoRealizado': '',
          'materiales': '',
          'anestesia': '',
          'indicacionesPost': '',
          'receta': '',
          'proximaCita': '',

          // auxiliares comunes en odonto
          'rx': '',
          'planTratamientoDental': '',
        });
        break;
    }

    base.putIfAbsent('horaEntrada', () => '');
    base.putIfAbsent('horaSalida', () => '');

    return base;
  }
}