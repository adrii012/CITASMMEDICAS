// lib/historia_editor_screen.dart
import 'package:flutter/material.dart';

import 'historia_clinica.dart';
import 'historias_store.dart';

class HistoriaEditorScreen extends StatefulWidget {
  // ✅ Compatibilidad: puedes mandar historia directo (preferido)
  final HistoriaClinica? historia;

  // ✅ Compatibilidad: o mandar historiaId + initial
  final String? historiaId;
  final HistoriaClinica? initial;

  const HistoriaEditorScreen({
    super.key,
    this.historia,
    this.historiaId,
    this.initial,
  });

  @override
  State<HistoriaEditorScreen> createState() => _HistoriaEditorScreenState();
}

class _HistoriaEditorScreenState extends State<HistoriaEditorScreen> {
  late HistoriaClinica _h;
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();

    final id = widget.historia?.id ?? widget.historiaId ?? widget.initial?.id;

    HistoriaClinica? existing;
    if (id != null && id.trim().isNotEmpty) {
      existing = HistoriasStore.porId(id);
    }

    _h = existing ?? widget.historia ?? widget.initial ?? _fallbackNueva();

    // Controllers por cada key existente
    _h.secciones.forEach((k, v) {
      _ctrls[k] = TextEditingController(text: v);
    });

    // Asegurar horaEntrada/horaSalida
    _ctrls.putIfAbsent('horaEntrada', () => TextEditingController(text: _h.horaEntrada));
    _ctrls.putIfAbsent('horaSalida', () => TextEditingController(text: _h.horaSalida));

    _h.secciones.putIfAbsent('horaEntrada', () => _h.horaEntrada);
    _h.secciones.putIfAbsent('horaSalida', () => _h.horaSalida);
  }

  HistoriaClinica _fallbackNueva() {
    final tipo = HistoriaTipo.general;
    return HistoriaClinica(
      id: 'his_${DateTime.now().microsecondsSinceEpoch}',
      pacienteId: '',
      createdAt: DateTime.now(),
      tipo: tipo,
      secciones: <String, String>{
        'horaEntrada': '',
        'horaSalida': '',
        'motivoConsulta': '',
        'padecimientoActual': '',
        'signosVitales': '',
        'exploracionFisica': '',
        'impresionDiagnostica': '',
        'plan': '',
        'tratamiento': '',
        'indicaciones': '',
        'notas': '',
      },
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ✅ Labels (incluye odontología)
  String _pretty(String key) {
    const map = {
      // tiempos
      'horaEntrada': 'Hora de entrada',
      'horaSalida': 'Hora de salida',

      // resumen base
      'motivoConsulta': 'Motivo de consulta',
      'padecimientoActual': 'Padecimiento actual',
      'inicioEvolucion': 'Inicio / evolución',
      'localizacion': 'Localización',
      'intensidad': 'Intensidad',
      'caracteristicas': 'Características',
      'factoresAgravantes': 'Factores agravantes',
      'factoresAtenuantes': 'Factores atenuantes',
      'sintomasAsociados': 'Síntomas asociados',
      'tratPrevio': 'Tratamiento previo',

      'signosVitales': 'Signos vitales (TA/FC/FR/T/SpO2)',
      'exploracionFisica': 'Exploración física',
      'impresionDiagnostica': 'Impresión diagnóstica',
      'dxDiferenciales': 'Diagnósticos diferenciales',
      'plan': 'Plan',
      'estudiosSolicitados': 'Estudios solicitados',
      'tratamiento': 'Tratamiento',
      'indicaciones': 'Indicaciones',
      'pronostico': 'Pronóstico',
      'notaEvolucion': 'Nota de evolución',
      'notas': 'Notas',

      // antecedentes
      'app': 'Antecedentes personales patológicos (APP)',
      'apnp': 'Antecedentes personales no patológicos (APNP)',
      'alergias': 'Alergias',
      'medicamentos': 'Medicamentos',
      'quirurgicos': 'Antecedentes quirúrgicos',
      'hospitalizaciones': 'Hospitalizaciones',
      'transfusiones': 'Transfusiones',
      'toxicomanias': 'Toxicomanías',
      'heredofamiliares': 'Heredofamiliares',
      'revisionSistemas': 'Revisión por sistemas',
      'vacunacion': 'Vacunación',
      'tamizajes': 'Tamizajes (PAP/Masto/etc.)',
      'estiloVida': 'Estilo de vida (dieta/ejercicio/sueño)',
      'riesgos': 'Riesgos (ocupacionales/otros)',
      'planSeguimiento': 'Plan de seguimiento',

      // GINE
      'g': 'G',
      'p': 'P',
      'c': 'C',
      'a': 'A (Abortos)',
      'e': 'E (Ectópicos)',
      'fUM': 'FUM',
      'fPP': 'FPP',
      'edadMenarca': 'Edad de menarca',
      'cicloMenstrual': 'Ciclo menstrual',
      'dismenorrea': 'Dismenorrea',
      'irs': 'Inicio de relaciones sexuales (IRS)',
      'parejasSexuales': 'Nº de parejas sexuales',
      'metodoAnticonceptivo': 'Método anticonceptivo',
      'its': 'ITS',
      'papanicolaou': 'Papanicolaou',
      'mastografia': 'Mastografía',
      'vidaSexual': 'Vida sexual',
      'sangrado': 'Sangrado',
      'flujo': 'Flujo',
      'dolorPelvico': 'Dolor pélvico',
      'dispareunia': 'Dispareunia',
      'embarazoActual': 'Embarazo actual',
      'movimientosFetales': 'Movimientos fetales',
      'contracciones': 'Contracciones',
      'perdidaLiquido': 'Pérdida de líquido',
      'signosAlarma': 'Signos de alarma',
      'exploracionGine': 'Exploración ginecológica',
      'especuloscopia': 'Especuloscopia',
      'tactoBimanual': 'Tacto bimanual',
      'fondoUterino': 'Fondo uterino',
      'fcf': 'Frecuencia cardiaca fetal (FCF)',
      'bh': 'BH',
      'ego': 'EGO',
      'pruebaEmbarazo': 'Prueba de embarazo',
      'usg': 'USG',

      // TRAUMA
      'mecanismoLesion': 'Mecanismo de lesión',
      'tiempoEvolucion': 'Tiempo de evolución',
      'sitioLesion': 'Sitio de lesión',
      'dominancia': 'Dominancia',
      'dolorEVA': 'Dolor (EVA)',
      'limitacionFuncional': 'Limitación funcional',
      'deformidad': 'Deformidad',
      'edemaEquimosis': 'Edema / equimosis',
      'heridas': 'Heridas',
      'sangradoActivo': 'Sangrado activo',
      'neurovascular': 'Estado neurovascular (resumen)',
      'pulsosDistales': 'Pulsos distales',
      'llenadoCapilar': 'Llenado capilar',
      'sensibilidad': 'Sensibilidad',
      'fuerza': 'Fuerza',
      'movilidad': 'Movilidad',
      'compartimental': 'Síndrome compartimental (datos)',
      'inspeccion': 'Inspección',
      'palpacion': 'Palpación',
      'rangoMov': 'Rango de movimiento (ROM)',
      'pruebasEspeciales': 'Pruebas especiales',
      'rxLabs': 'RX / Labs (resumen)',
      'rx': 'RX',
      'tac': 'TAC',
      'rm': 'RM',
      'analgesia': 'Analgesia',
      'reduccion': 'Reducción',
      'inmovilizacion': 'Inmovilización',
      'férulaYeso': 'Férula / yeso',
      'curacion': 'Curación',
      'profilaxisTetanos': 'Profilaxis tétanos',
      'antibiotico': 'Antibiótico',
      'interconsulta': 'Interconsulta',
      'referencia': 'Referencia',
      'incapacidad': 'Incapacidad',
      'rehabilitacion': 'Rehabilitación',

      // URGENCIAS
      'triage': 'Triage',
      'prioridad': 'Prioridad',
      'aViaAerea': 'A: Vía aérea',
      'bRespiracion': 'B: Respiración',
      'cCirculacion': 'C: Circulación',
      'dNeurologico': 'D: Neurológico',
      'eExposicion': 'E: Exposición',
      'glasgow': 'Glasgow',
      'pupilas': 'Pupilas',
      'deficitFocal': 'Déficit focal',
      'convulsiones': 'Convulsiones',
      'intervenciones': 'Intervenciones',
      'liquidosIV': 'Líquidos IV',
      'oxigeno': 'Oxígeno',
      'medsAdministrados': 'Medicamentos administrados',
      'procedimientos': 'Procedimientos',
      'estudiosUrgencias': 'Estudios en urgencias',
      'ekg': 'EKG',
      'gases': 'Gases',
      'labs': 'Labs',
      'imagen': 'Imagen',
      'respuestaTratamiento': 'Respuesta a tratamiento',
      'disposicion': 'Disposición (alta/obs/ingreso/ref)',
      'criteriosAlta': 'Criterios de alta',

      // ✅ ODONTOLOGÍA
      'diagnosticoDental': 'Diagnóstico dental',
      'odontograma': 'Odontograma / piezas',
      'tejidosBlandos': 'Tejidos blandos',
      'encias': 'Encías',
      'atm': 'ATM',
      'oclusion': 'Oclusión',
      'procedimientoRealizado': 'Procedimiento realizado',
      'materiales': 'Materiales',
      'anestesia': 'Anestesia',
      'indicacionesPost': 'Indicaciones post-tratamiento',
      'receta': 'Receta',
      'proximaCita': 'Próxima cita',
      'pieza': 'Pieza dental',
      'motivoConsultaDental': 'Motivo dental (específico)',
    };

    return map[key] ?? key;
  }

  bool _isMultiline(String key) {
    const multi = {
      'motivoConsulta',
      'padecimientoActual',
      'signosVitales',
      'exploracionFisica',
      'impresionDiagnostica',
      'dxDiferenciales',
      'plan',
      'estudiosSolicitados',
      'tratamiento',
      'indicaciones',
      'pronostico',
      'notaEvolucion',
      'notas',
      'app',
      'apnp',
      'quirurgicos',
      'hospitalizaciones',
      'transfusiones',
      'toxicomanias',
      'heredofamiliares',
      'revisionSistemas',
      'caracteristicas',
      'factoresAgravantes',
      'factoresAtenuantes',
      'sintomasAsociados',
      'tratPrevio',
      'tamizajes',
      'estiloVida',
      'riesgos',
      'planSeguimiento',

      // Gine/Trauma/Urg
      'its',
      'signosAlarma',
      'exploracionGine',
      'especuloscopia',
      'tactoBimanual',
      'embarazoActual',
      'neurovascular',
      'compartimental',
      'inspeccion',
      'palpacion',
      'pruebasEspeciales',
      'rxLabs',
      'analgesia',
      'reduccion',
      'inmovilizacion',
      'curacion',
      'interconsulta',
      'referencia',
      'rehabilitacion',
      'aViaAerea',
      'bRespiracion',
      'cCirculacion',
      'dNeurologico',
      'eExposicion',
      'intervenciones',
      'medsAdministrados',
      'procedimientos',
      'estudiosUrgencias',
      'respuestaTratamiento',
      'disposicion',
      'criteriosAlta',

      // ✅ Odonto
      'diagnosticoDental',
      'odontograma',
      'tejidosBlandos',
      'encias',
      'atm',
      'oclusion',
      'procedimientoRealizado',
      'materiales',
      'anestesia',
      'indicacionesPost',
      'receta',
      'proximaCita',
      'motivoConsultaDental',
    };
    return multi.contains(key);
  }

  int _linesFor(String key) => _isMultiline(key) ? 4 : 1;

  TextInputType _keyboardFor(String key) {
    if (key == 'horaEntrada' || key == 'horaSalida') return TextInputType.datetime;

    const numeric = {
      'g',
      'p',
      'c',
      'a',
      'e',
      'dolorEVA',
      'glasgow',
      'parejasSexuales',
      'edadMenarca',
      'pieza', // puede ser num (pero a veces ponen 2.6)
    };
    if (numeric.contains(key)) return TextInputType.text;

    return TextInputType.text;
  }

  Widget _field(String key) {
    final c = _ctrls.putIfAbsent(
      key,
      () => TextEditingController(text: _h.secciones[key] ?? ''),
    );

    final isHour = (key == 'horaEntrada' || key == 'horaSalida');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: _keyboardFor(key),
        maxLines: _linesFor(key),
        decoration: InputDecoration(
          labelText: _pretty(key),
          border: const OutlineInputBorder(),
          hintText: isHour ? 'Ej: 14:20' : null,
        ),
      ),
    );
  }

  void _ensureKeys(List<String> keys) {
    for (final k in keys) {
      _h.secciones.putIfAbsent(k, () => '');
      _ctrls.putIfAbsent(k, () => TextEditingController(text: _h.secciones[k] ?? ''));
    }
  }

  void _guardar() {
    for (final e in _ctrls.entries) {
      _h.secciones[e.key] = e.value.text.trim();
    }

    _h.horaEntrada = _ctrls['horaEntrada']!.text;
    _h.horaSalida = _ctrls['horaSalida']!.text;

    HistoriasStore.upsert(_h);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final keysHoras = ['horaEntrada', 'horaSalida'];

    final keysResumen = [
      'motivoConsulta',
      'padecimientoActual',
      'inicioEvolucion',
      'localizacion',
      'intensidad',
      'caracteristicas',
      'sintomasAsociados',
      'signosVitales',
      'exploracionFisica',
      'impresionDiagnostica',
      'dxDiferenciales',
      'plan',
      'tratamiento',
      'estudiosSolicitados',
      'indicaciones',
      'pronostico',
      'notaEvolucion',
      'notas',
    ];

    final keysAntecedentes = [
      'app',
      'apnp',
      'heredofamiliares',
      'alergias',
      'medicamentos',
      'quirurgicos',
      'hospitalizaciones',
      'transfusiones',
      'toxicomanias',
      'vacunacion',
      'tamizajes',
      'estiloVida',
      'riesgos',
      'revisionSistemas',
      'planSeguimiento',
    ];

    final keysGine = [
      'g',
      'p',
      'c',
      'a',
      'e',
      'fUM',
      'fPP',
      'edadMenarca',
      'cicloMenstrual',
      'dismenorrea',
      'irs',
      'parejasSexuales',
      'metodoAnticonceptivo',
      'its',
      'papanicolaou',
      'mastografia',
      'vidaSexual',
      'sangrado',
      'flujo',
      'dolorPelvico',
      'dispareunia',
      'embarazoActual',
      'movimientosFetales',
      'contracciones',
      'perdidaLiquido',
      'signosAlarma',
      'exploracionGine',
      'especuloscopia',
      'tactoBimanual',
      'fondoUterino',
      'fcf',
      'bh',
      'ego',
      'pruebaEmbarazo',
      'usg',
    ];

    final keysTrauma = [
      'mecanismoLesion',
      'tiempoEvolucion',
      'sitioLesion',
      'dominancia',
      'dolorEVA',
      'limitacionFuncional',
      'deformidad',
      'edemaEquimosis',
      'heridas',
      'sangradoActivo',
      'neurovascular',
      'pulsosDistales',
      'llenadoCapilar',
      'sensibilidad',
      'fuerza',
      'movilidad',
      'compartimental',
      'inspeccion',
      'palpacion',
      'rangoMov',
      'pruebasEspeciales',
      'rxLabs',
      'rx',
      'tac',
      'rm',
      'analgesia',
      'reduccion',
      'inmovilizacion',
      'férulaYeso',
      'curacion',
      'profilaxisTetanos',
      'antibiotico',
      'interconsulta',
      'referencia',
      'incapacidad',
      'rehabilitacion',
    ];

    final keysUrg = [
      'triage',
      'prioridad',
      'aViaAerea',
      'bRespiracion',
      'cCirculacion',
      'dNeurologico',
      'eExposicion',
      'glasgow',
      'pupilas',
      'deficitFocal',
      'convulsiones',
      'intervenciones',
      'liquidosIV',
      'oxigeno',
      'medsAdministrados',
      'procedimientos',
      'estudiosUrgencias',
      'ekg',
      'gases',
      'labs',
      'imagen',
      'respuestaTratamiento',
      'disposicion',
      'criteriosAlta',
    ];

    // ✅ ODONTO
    final keysOdonto = [
      'motivoConsultaDental',
      'dolorEVA',
      'pieza',
      'diagnosticoDental',
      'odontograma',
      'tejidosBlandos',
      'encias',
      'atm',
      'oclusion',
      'procedimientoRealizado',
      'materiales',
      'anestesia',
      'indicacionesPost',
      'receta',
      'proximaCita',
    ];

    _ensureKeys(keysHoras);
    _ensureKeys(keysResumen);
    _ensureKeys(keysAntecedentes);

    if (_h.tipo == HistoriaTipo.gine) _ensureKeys(keysGine);
    if (_h.tipo == HistoriaTipo.trauma) _ensureKeys(keysTrauma);
    if (_h.tipo == HistoriaTipo.urgencias) _ensureKeys(keysUrg);
    if (_h.tipo == HistoriaTipo.odontologia) _ensureKeys(keysOdonto);

    final grouped = <String>{
      ...keysHoras,
      ...keysResumen,
      ...keysAntecedentes,
      ...keysGine,
      ...keysTrauma,
      ...keysUrg,
      ...keysOdonto,
    };

    final extras = _h.secciones.keys.where((k) => !grouped.contains(k)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar historia clínica'),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            icon: const Icon(Icons.save),
            onPressed: _guardar,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tipo: ${_h.tipo.name.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Horas siempre arriba
          ...keysHoras.map(_field),

          Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.assignment),
              title: const Text('Resumen clínico'),
              subtitle: const Text('Motivo, padecimiento, SV, exploración, Dx, plan'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(children: keysResumen.map(_field).toList()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Card(
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: const Icon(Icons.history_edu),
              title: const Text('Antecedentes'),
              subtitle: const Text('APP, APNP, heredofamiliares, alergias, etc.'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(children: keysAntecedentes.map(_field).toList()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (_h.tipo == HistoriaTipo.odontologia) ...[
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.medical_information),
                title: const Text('Odontología'),
                subtitle: const Text('Pieza, diagnóstico, procedimiento, indicaciones'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(children: keysOdonto.map(_field).toList()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_h.tipo == HistoriaTipo.gine) ...[
            Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.female),
                title: const Text('Ginecología / Obstetricia'),
                subtitle: const Text('G/P/C, FUM, FPP, exploración gine, etc.'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(children: keysGine.map(_field).toList()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_h.tipo == HistoriaTipo.trauma) ...[
            Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.health_and_safety),
                title: const Text('Trauma / Ortopedia'),
                subtitle: const Text('Mecanismo, EVA, neurovascular, inmovilización, etc.'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(children: keysTrauma.map(_field).toList()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_h.tipo == HistoriaTipo.urgencias) ...[
            Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.emergency),
                title: const Text('Urgencias'),
                subtitle: const Text('ABCDE, Glasgow, intervenciones, disposición, etc.'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(children: keysUrg.map(_field).toList()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (extras.isNotEmpty) ...[
            Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.more_horiz),
                title: const Text('Otros campos'),
                subtitle: Text('${extras.length} extra'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(children: extras.map(_field).toList()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}