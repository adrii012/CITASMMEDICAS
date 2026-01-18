// lib/historia_clinica.dart
enum HistoriaTipo { general, gine, trauma, urgencias }

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
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
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
        // ✅ Ginecología / Obstetricia básica + completa
        base.addAll({
          // gine-obs clave
          'g': '',
          'p': '',
          'c': '',
          'a': '', // abortos
          'e': '', // ectópicos (si quieres)
          'fUM': '',
          'fPP': '',
          'edadMenarca': '',
          'cicloMenstrual': '', // regularidad/duración
          'dismenorrea': '',
          'irs': '', // inicio de relaciones sexuales
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
          'embarazoActual': '', // si aplica
          'movimientosFetales': '', // si aplica
          'contracciones': '', // si aplica
          'perdidaLiquido': '', // si aplica
          'signosAlarma': '',

          // exploración gine
          'exploracionGine': '',
          'especuloscopia': '',
          'tactoBimanual': '',
          'fondoUterino': '', // obstetricia
          'fcf': '', // frecuencia cardiaca fetal

          // labs/imagen comunes
          'bh': '',
          'ego': '',
          'pruebaEmbarazo': '',
          'usg': '',
        });
        break;

      case HistoriaTipo.trauma:
        // ✅ Trauma / Ortopedia completa
        base.addAll({
          // evento
          'mecanismoLesion': '',
          'tiempoEvolucion': '',
          'sitioLesion': '',
          'dominancia': '', // mano dominante si aplica
          'dolorEVA': '',
          'limitacionFuncional': '',
          'deformidad': '',
          'edemaEquimosis': '',
          'heridas': '',
          'sangradoActivo': '',

          // neurovascular
          'neurovascular': '', // pulsos, llenado capilar, sensibilidad, motor
          'pulsosDistales': '',
          'llenadoCapilar': '',
          'sensibilidad': '',
          'fuerza': '',
          'movilidad': '',
          'compartimental': '', // datos de síndrome compartimental

          // exploración dirigida
          'inspeccion': '',
          'palpacion': '',
          'rangoMov': '',
          'pruebasEspeciales': '',

          // estudios
          'rxLabs': '',
          'rx': '',
          'tac': '',
          'usg': '',
          'rm': '',

          // manejo
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
        // ✅ Urgencias completa (triage/ABCDE)
        base.addAll({
          // triage y motivo
          'triage': '',
          'prioridad': '',

          // ABCDE
          'aViaAerea': '',
          'bRespiracion': '',
          'cCirculacion': '',
          'dNeurologico': '',
          'eExposicion': '',

          // neurológico
          'glasgow': '',
          'pupilas': '',
          'deficitFocal': '',
          'convulsiones': '',

          // respiratorio/cardiovascular
          'dolorToracico': '',
          'disnea': '',
          'tos': '',
          'sibilancias': '',
          'estertores': '',
          'edema': '',
          'perfusión': '',

          // GI/otros
          'dolorAbdominal': '',
          'vomito': '',
          'diarrea': '',
          'diuresis': '',

          // antecedentes urgencias
          'ultimoAlimento': '',
          'eventosPrevios': '',
          'riesgoTrombotico': '',

          // intervenciones
          'intervenciones': '',
          'liquidosIV': '',
          'oxigeno': '',
          'medsAdministrados': '',
          'procedimientos': '',

          // estudios urgencias
          'estudiosUrgencias': '',
          'ekg': '',
          'gases': '',
          'labs': '',
          'imagen': '',

          // destino
          'respuestaTratamiento': '',
          'disposicion': '', // alta/observación/ingreso/referencia
          'criteriosAlta': '',
          'signosAlarma': '',
        });
        break;
    }

    // ✅ Por si el usuario borra llaves sin querer, volvemos a asegurar horas
    base.putIfAbsent('horaEntrada', () => '');
    base.putIfAbsent('horaSalida', () => '');

    return base;
  }
}