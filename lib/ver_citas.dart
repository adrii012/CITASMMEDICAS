import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'citas_store.dart';
import 'agendar_cita.dart';

import 'pacientes_store.dart';
import 'export_pdf.dart';
import 'export_csv.dart';
import 'whatsapp_helper.dart';

import 'auth_store.dart';
import 'fire_appointments.dart';

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

  // ---------- Helpers Firestore -> Modelo ----------
  DateTime _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  EstadoCita _statusToEstado(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'realizada':
        return EstadoCita.realizada;
      case 'confirmada':
        return EstadoCita.realizada;
      case 'cancelada':
        return EstadoCita.cancelada;
      case 'reagendar_solicitado':
        return EstadoCita.pendiente;
      case 'pendiente':
      default:
        return EstadoCita.pendiente;
    }
  }

  String _estadoToStatus(EstadoCita e) {
    switch (e) {
      case EstadoCita.pendiente:
        return 'pendiente';
      case EstadoCita.realizada:
        return 'realizada';
      case EstadoCita.cancelada:
        return 'cancelada';
    }
  }

  String _estadoLabel(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'confirmada':
        return 'confirmada';
      case 'reagendar_solicitado':
        return 'reagendar solicitada';
      case 'realizada':
        return 'realizada';
      case 'cancelada':
        return 'cancelada';
      case 'pendiente':
      default:
        return 'pendiente';
    }
  }

  Cita _mapToCita(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final startAt = _toDate(m['startAt']);
    final patientName = (m['patientName'] ?? '').toString();
    final patientId = (m['patientId'] ?? '').toString();
    final notes = (m['notes'] ?? '').toString();
    final durationMin = (m['durationMin'] is int) ? (m['durationMin'] as int) : 30;
    final estado = _statusToEstado(m['status']);

    return Cita(
      id: id,
      paciente: patientName,
      pacienteId: patientId.isEmpty ? null : patientId,
      fechaHora: startAt,
      estado: estado,
      notas: notes,
      duracionMin: durationMin,
    );
  }

  // ---------- UI helpers ----------
  Color _colorEstadoRaw(String s) {
    switch (s.toLowerCase().trim()) {
      case 'confirmada':
        return Colors.green;
      case 'realizada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      case 'reagendar_solicitado':
        return Colors.orange;
      case 'pendiente':
      default:
        return Colors.amber;
    }
  }

  String _fechaTexto(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ---------- Export ----------
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
          FilledButton(
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

    final pid = await _seleccionarPacienteId();
    if (pid == null) return;

    final list = base.where((c) => c.pacienteId == pid).toList();

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

  // ---------- Mensajes ----------
  Future<void> _enviarRecordatorioClienteCompartir(Cita c) async {
    final fecha = _fechaTexto(c.fechaHora);
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

  /// ✅ WhatsApp: usa teléfono del paciente local y si no existe, usa appointments.phone
  Future<void> _enviarRecordatorioWhatsApp(Cita c) async {
    // 1) local
    final p = PacientesStore.porId(c.pacienteId ?? '');
    String tel = (p?.telefono ?? '').trim();

    // 2) fallback Firestore: appointments/{id}.phone
    if (tel.isEmpty) {
      final clinicId = AuthStore.requireClinicId();
      final doc = await FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .collection('appointments')
          .doc(c.id)
          .get();

      tel = (doc.data()?['phone'] ?? '').toString().trim();
    }

    if (tel.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta cita no tiene teléfono guardado')),
      );
      return;
    }

    final fecha = _fechaTexto(c.fechaHora);
    final hora =
        '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';

    final msg = 'Recordatorio de cita\n'
        'Paciente: ${c.paciente}\n'
        'Fecha: $fecha\n'
        'Hora: $hora\n'
        'Notas: ${c.notas.isEmpty ? "-" : c.notas}';

    final ok = await WhatsAppHelper.enviar(
      phone: tel,
      message: msg,
      defaultCountryCode: '52',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'WhatsApp abierto ✅' : 'No se pudo abrir WhatsApp ❌ (revisa popups)')),
    );
  }

  // ---------- Firestore actions ----------
  Future<void> _marcarRealizada(Cita c) async {
    final clinicId = AuthStore.requireClinicId();
    final uid = AuthStore.uid.value ?? 'unknown';

    await FireAppointments.updateStatus(
      clinicId: clinicId,
      appointmentId: c.id,
      updatedByUid: uid,
      status: _estadoToStatus(EstadoCita.realizada),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marcada como realizada ✅')),
    );
  }

  Future<void> _marcarCancelada(Cita c) async {
    final clinicId = AuthStore.requireClinicId();
    final uid = AuthStore.uid.value ?? 'unknown';

    await FireAppointments.updateStatus(
      clinicId: clinicId,
      appointmentId: c.id,
      updatedByUid: uid,
      status: _estadoToStatus(EstadoCita.cancelada),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marcada como cancelada ❌')),
    );
  }

  Future<void> _eliminarCita(Cita c) async {
    final clinicId = AuthStore.requireClinicId();
    await FireAppointments.delete(clinicId: clinicId, appointmentId: c.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cita eliminada 🗑️')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = AuthStore.requireClinicId();
    final q = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis citas (en vivo)'),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FireAppointments.streamUpcoming(
                clinicId: clinicId,
                from: DateTime.now().subtract(const Duration(days: 60)),
                limit: 700,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator()),
                  );
                }

                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error Firestore: ${snap.error}'),
                    ),
                  );
                }

                final raw = snap.data ?? const [];
                final base = raw.map(_mapToCita).toList()
                  ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

                final citas = q.isEmpty
                    ? base
                    : base.where((c) {
                        final fecha = _fechaTexto(c.fechaHora).toLowerCase();
                        return c.paciente.toLowerCase().contains(q) ||
                            fecha.contains(q) ||
                            c.notas.toLowerCase().contains(q) ||
                            c.estado.name.toLowerCase().contains(q);
                      }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _exportarMenu(base),
                          icon: const Icon(Icons.share),
                          label: const Text('Exportar (PDF/CSV)'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: citas.isEmpty
                          ? const Center(child: Text('No hay citas'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: citas.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final c = citas[index];
                                final rawStatus = (raw[index]['status'] ?? '').toString();

                                final fecha = _fechaTexto(c.fechaHora);
                                final hora =
                                    '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';

                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _colorEstadoRaw(rawStatus),
                                      child: const Icon(Icons.event, color: Colors.white),
                                    ),
                                    title: Text(c.paciente),
                                    subtitle: Text(
                                      'Fecha: $fecha  •  Hora: $hora\n'
                                      'Estado: ${_estadoLabel(rawStatus)}\n'
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
                                              builder: (_) => AgendarCitaScreen(citaParaEditar: c),
                                            ),
                                          );
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}