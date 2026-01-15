import 'package:flutter/material.dart';

import 'citas_store.dart';
import 'pacientes_store.dart';

class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _mesNombre(int m) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return meses[(m - 1).clamp(0, 11)];
  }

  // Normaliza a inicio de mes
  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  List<DateTime> _ultimos6Meses(DateTime ahora) {
    final list = <DateTime>[];
    for (int i = 5; i >= 0; i--) {
      list.add(DateTime(ahora.year, ahora.month - i, 1));
    }
    return list;
  }

  String _keyMes(DateTime d) => '${d.year}-${d.month}';

  DateTime? _tryParseIso(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final citas = CitasStore.citasOrdenadas;
    final total = citas.length;

    final pendientes =
        citas.where((c) => c.estado == EstadoCita.pendiente).length;
    final realizadas =
        citas.where((c) => c.estado == EstadoCita.realizada).length;
    final canceladas =
        citas.where((c) => c.estado == EstadoCita.cancelada).length;

    final prox7 = citas.where((c) {
      final d = c.fechaHora;
      return d.isAfter(ahora) && d.isBefore(ahora.add(const Duration(days: 7)));
    }).length;

    final mesActual = citas
        .where((c) => c.fechaHora.year == ahora.year && c.fechaHora.month == ahora.month)
        .length;

    // -------------------------
    // 1) GRAFICA POR MES (6 meses) - CITAS
    // -------------------------
    final meses = _ultimos6Meses(ahora);

    final conteoMesCitas = <String, int>{
      for (final m in meses) _keyMes(m): 0,
    };

    for (final c in citas) {
      final key = _keyMes(c.fechaHora);
      if (conteoMesCitas.containsKey(key)) {
        conteoMesCitas[key] = (conteoMesCitas[key] ?? 0) + 1;
      }
    }

    final valoresMesCitas =
        meses.map((m) => conteoMesCitas[_keyMes(m)] ?? 0).toList();
    final maxMesCitas = valoresMesCitas.isEmpty
        ? 0
        : valoresMesCitas.reduce((a, b) => a > b ? a : b);

    // -------------------------
    // 2) HORAS MAS OCUPADAS (Top 5)
    // -------------------------
    final porHora = List<int>.filled(24, 0);
    for (final c in citas) {
      porHora[c.fechaHora.hour] += 1;
    }

    final horasOrdenadas = List.generate(24, (i) => i)
      ..sort((a, b) => porHora[b].compareTo(porHora[a]));
    final topHoras = horasOrdenadas.take(5).toList();
    final maxHora = porHora.reduce((a, b) => a > b ? a : b);

    // -------------------------
    // 3) TIEMPO PROMEDIO CONSULTA REAL (usa duracionMin)
    // -------------------------
    int totalMin = 0;
    for (final c in citas) {
      totalMin += (c.duracionMin > 0 ? c.duracionMin : 30);
    }
    final promedioMin = total == 0 ? 0 : (totalMin / total).round();

    // (opcional extra útil) promedio solo realizadas:
    int totalMinReal = 0;
    for (final c in citas.where((x) => x.estado == EstadoCita.realizada)) {
      totalMinReal += (c.duracionMin > 0 ? c.duracionMin : 30);
    }
    final promedioMinRealizadas =
        realizadas == 0 ? 0 : (totalMinReal / realizadas).round();

    // -------------------------
    // 4) TOP PACIENTES por # citas
    // -------------------------
    final Map<String, int> conteoPaciente = {};
    for (final c in citas) {
      final key = (c.pacienteId != null && c.pacienteId!.trim().isNotEmpty)
          ? c.pacienteId!.trim()
          : 'name:${c.paciente.trim()}';
      conteoPaciente[key] = (conteoPaciente[key] ?? 0) + 1;
    }

    final top = conteoPaciente.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String nombreDeKey(String key) {
      if (key.startsWith('name:')) return key.substring(5);
      final p = PacientesStore.porId(key);
      return p?.nombre ?? '(Paciente)';
    }

    // -------------------------
    // 5) MEJOR DIA DE LA SEMANA
    // -------------------------
    final porDiaSemana = List<int>.filled(8, 0); // 1..7
    for (final c in citas) {
      porDiaSemana[c.fechaHora.weekday] += 1;
    }

    int mejorDia = 1;
    for (int d = 2; d <= 7; d++) {
      if (porDiaSemana[d] > porDiaSemana[mejorDia]) mejorDia = d;
    }

    const dias = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final mejorDiaNombre = dias[mejorDia];
    final mejorDiaTotal = porDiaSemana[mejorDia];

    // -------------------------
    // 6) PACIENTES NUEVOS POR MES (6 meses)
    // -------------------------
    final pacientes = PacientesStore.pacientes;

    final conteoMesPacientes = <String, int>{
      for (final m in meses) _keyMes(m): 0,
    };

    for (final p in pacientes) {
      final created = _tryParseIso(p.createdAtIso);
      if (created == null) continue;
      final k = _keyMes(_monthStart(created));
      if (conteoMesPacientes.containsKey(k)) {
        conteoMesPacientes[k] = (conteoMesPacientes[k] ?? 0) + 1;
      }
    }

    final valoresMesPacientes =
        meses.map((m) => conteoMesPacientes[_keyMes(m)] ?? 0).toList();
    final maxMesPacientes = valoresMesPacientes.isEmpty
        ? 0
        : valoresMesPacientes.reduce((a, b) => a > b ? a : b);

    // -------------------------
    // UI helpers
    // -------------------------
    Widget pill(String label, int value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 8),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    Widget barraProgreso({
      required String label,
      required int value,
      required int max,
      required IconData icon,
    }) {
      final ratio = (max <= 0) ? 0.0 : (value / max).clamp(0.0, 1.0);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text('$value'),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: ratio, minHeight: 10),
              ),
            ],
          ),
        ),
      );
    }

    Widget graficaBarras({
      required String titulo,
      required List<DateTime> meses,
      required List<int> valores,
      required int max,
    }) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (max <= 0)
                const Text('Aún no hay datos')
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(meses.length, (i) {
                    final m = meses[i];
                    final v = valores[i];
                    final h = (v / max) * 120.0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$v',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              height: h < 6 ? 6 : h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_mesNombre(m.month),
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      );
    }

    Widget horasOcupadas() {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Horas más ocupadas (Top 5)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (maxHora <= 0)
                const Text('Aún no hay datos')
              else
                ...topHoras.map((h) {
                  final v = porHora[h];
                  final ratio = (maxHora <= 0) ? 0.0 : (v / maxHora).clamp(0.0, 1.0);
                  final etiqueta = '${h.toString().padLeft(2, '0')}:00';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(etiqueta,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Text('$v'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(value: ratio, minHeight: 10),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      );
    }

    final proximas = citas.where((c) => c.fechaHora.isAfter(ahora)).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      pill('Total', total),
                      pill('Pendientes', pendientes),
                      pill('Realizadas', realizadas),
                      pill('Canceladas', canceladas),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Hoy: ${_fmt(hoy)}'),
                  Text('Próximas 7 días: $prox7'),
                  Text('Mes actual: $mesActual'),
                  const SizedBox(height: 8),
                  Text('Tiempo promedio (todas): $promedioMin min'),
                  Text('Tiempo promedio (realizadas): $promedioMinRealizadas min'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          barraProgreso(label: 'Pendientes', value: pendientes, max: total, icon: Icons.schedule),
          barraProgreso(label: 'Realizadas', value: realizadas, max: total, icon: Icons.check_circle),
          barraProgreso(label: 'Canceladas', value: canceladas, max: total, icon: Icons.cancel),

          const SizedBox(height: 10),

          graficaBarras(
            titulo: 'Citas por mes (últimos 6)',
            meses: meses,
            valores: valoresMesCitas,
            max: maxMesCitas,
          ),

          const SizedBox(height: 10),

          graficaBarras(
            titulo: 'Pacientes nuevos por mes (últimos 6)',
            meses: meses,
            valores: valoresMesPacientes,
            max: maxMesPacientes,
          ),

          const SizedBox(height: 10),

          horasOcupadas(),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mejor día de la semana',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Día más cargado: $mejorDiaNombre'),
                  Text('Citas ese día: $mejorDiaTotal'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top pacientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (top.isEmpty)
                    const Text('Aún no hay datos')
                  else
                    ...top.take(5).map((e) {
                      final name = nombreDeKey(e.key);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(name),
                        trailing: Text('${e.value}'),
                      );
                    }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Próximas citas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (proximas.isEmpty)
                    const Text('No hay próximas citas')
                  else
                    ...proximas.map((c) {
                      final fecha = _fmt(c.fechaHora);
                      final hora =
                          '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(c.paciente),
                        subtitle: Text('$fecha  •  $hora  •  ${c.duracionMin} min'),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}