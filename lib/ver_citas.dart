import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'citas_store.dart';
import 'agendar_cita.dart';
import 'persistencia.dart';
import 'notificaciones.dart';

import 'pacientes_store.dart';
import 'export_pdf.dart';
import 'export_csv.dart';

import 'whatsapp_helper.dart';

class VerCitasScreen extends StatefulWidget {
  const VerCitasScreen({super.key});

  @override
  State<VerCitasScreen> createState() => _VerCitasScreenState();
}

class _VerCitasScreenState extends State<VerCitasScreen> {
  final _buscarCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Color _colorEstado(EstadoCita e) {
    switch (e) {
      case EstadoCita.pendiente:
        return Colors.amber;
      case EstadoCita.realizada:
        return Colors.green;
      case EstadoCita.cancelada:
        return Colors.red;
    }
  }

  Future<String?> _seleccionarPacienteId() async {
    final pacientes = PacientesStore.pacientes;
    if (pacientes.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pacientes')),
      );
      return null;
    }

    String? id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elegir paciente'),
        content: DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Paciente',
          ),
          items: pacientes
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)))
              .toList(),
          onChanged: (v) => id = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (ok != true) return null;
    return id;
  }

  Future<void> _exportarMenu(List<Cita> base) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Exportar PDF (todas)'),
              onTap: () => Navigator.pop(context, 'pdf_all'),
            ),
            ListTile(
              leading: const Icon(Icons.table_view),
              title: const Text('Exportar CSV (todas)'),
              onTap: () => Navigator.pop(context, 'csv_all'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Exportar PDF por paciente'),
              onTap: () => Navigator.pop(context, 'pdf_p'),
            ),
            ListTile(
              leading: const Icon(Icons.table_view),
              title: const Text('Exportar CSV por paciente'),
              onTap: () => Navigator.pop(context, 'csv_p'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'pdf_all') {
      await ExportPdf.generarYCompartir(context, base);
      return;
    }
    if (choice == 'csv_all') {
      await ExportCsv.exportar(context, base);
      return;
    }

    // por paciente
    final pid = await _seleccionarPacienteId();
    if (pid == null) return;

    final list =
        CitasStore.citasOrdenadas.where((c) => c.pacienteId == pid).toList();

    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese paciente no tiene citas')),
      );
      return;
    }

    if (choice == 'pdf_p') {
      await ExportPdf.generarYCompartir(context, list);
      return;
    }
    if (choice == 'csv_p') {
      await ExportCsv.exportar(context, list);
      return;
    }
  }

  Future<void> _enviarRecordatorioClienteCompartir(Cita c) async {
    final fecha = '${c.fechaHora.day}/${c.fechaHora.month}/${c.fechaHora.year}';
    final hora =
        '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';

    final texto = 'Recordatorio de cita\n'
        'Paciente: ${c.paciente}\n'
        'Fecha: $fecha\n'
        'Hora: $hora\n'
        'Notas: ${c.notas.isEmpty ? "-" : c.notas}\n'
        'Estado: ${c.estado.name}';

    await Share.share(texto);
  }

  Future<void> _enviarRecordatorioWhatsApp(Cita c) async {
    // Tomar teléfono del paciente real si existe
    final p = PacientesStore.porId(c.pacienteId ?? '');
    final tel = (p?.telefono ?? '').trim();

    if (tel.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese paciente no tiene teléfono')),
      );
      return;
    }

    final fecha = '${c.fechaHora.day}/${c.fechaHora.month}/${c.fechaHora.year}';
    final hora =
        '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';

    final msg = 'Recordatorio de cita\n'
        'Paciente: ${c.paciente}\n'
        'Fecha: $fecha\n'
        'Hora: $hora\n'
        'Notas: ${c.notas.isEmpty ? "-" : c.notas}';

    final ok = await WhatsAppHelper.enviar(phone: tel, message: msg);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'WhatsApp abierto ✅' : 'No se pudo abrir WhatsApp ❌')),
    );
  }

  Future<void> _marcarRealizada(Cita c) async {
    setState(() => CitasStore.setEstado(c.id, EstadoCita.realizada));
    await PersistenciaCitas.guardar();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marcada como realizada ✅')),
    );
  }

  Future<void> _marcarCancelada(Cita c) async {
    setState(() => CitasStore.setEstado(c.id, EstadoCita.cancelada));

    await Notificaciones.cancelar(c.id);
    await PersistenciaCitas.guardar();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marcada como cancelada ❌')),
    );
  }

  Future<void> _eliminarCita(Cita c) async {
    await Notificaciones.cancelar(c.id);

    setState(() => CitasStore.eliminar(c.id));
    await PersistenciaCitas.guardar();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cita eliminada 🗑️')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = CitasStore.citasOrdenadas;
    final q = _query.trim().toLowerCase();

    final citas = q.isEmpty
        ? base
        : base.where((c) {
            final fecha =
                '${c.fechaHora.day}/${c.fechaHora.month}/${c.fechaHora.year}';
            return c.paciente.toLowerCase().contains(q) ||
                fecha.toLowerCase().contains(q) ||
                c.notas.toLowerCase().contains(q) ||
                c.estado.name.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis citas'),
        actions: [
          IconButton(
            tooltip: 'Exportar',
            icon: const Icon(Icons.share),
            onPressed: () => _exportarMenu(base),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _buscarCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por nombre, fecha, notas o estado…',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscarCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: citas.isEmpty
                ? const Center(child: Text('No hay citas'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: citas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = citas[index];

                      final fecha =
                          '${c.fechaHora.day}/${c.fechaHora.month}/${c.fechaHora.year}';
                      final hora =
                          '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _colorEstado(c.estado),
                            child: const Icon(Icons.event, color: Colors.white),
                          ),
                          title: Text(c.paciente),
                          subtitle: Text(
                            'Fecha: $fecha  •  Hora: $hora\n'
                            'Estado: ${c.estado.name}\n'
                            '${c.notas.isEmpty ? "(sin notas)" : c.notas}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'wa') return _enviarRecordatorioWhatsApp(c);
                              if (v == 'share') return _enviarRecordatorioClienteCompartir(c);

                              if (v == 'realizada') return _marcarRealizada(c);
                              if (v == 'cancelada') return _marcarCancelada(c);

                              if (v == 'editar') {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AgendarCitaScreen(citaParaEditar: c),
                                  ),
                                );
                                setState(() {});
                                return;
                              }

                              if (v == 'eliminar') return _eliminarCita(c);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'wa', child: Text('Enviar por WhatsApp')),
                              PopupMenuItem(value: 'share', child: Text('Compartir (cualquier app)')),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'realizada', child: Text('Marcar realizada')),
                              PopupMenuItem(value: 'cancelada', child: Text('Marcar cancelada')),
                              PopupMenuItem(value: 'editar', child: Text('Editar')),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}