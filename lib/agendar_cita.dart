// lib/agendar_cita.dart
import 'package:flutter/material.dart';

import 'citas_store.dart';
import 'persistencia.dart';
import 'notificaciones.dart';

import 'pacientes_store.dart';
import 'persistencia_pacientes.dart';
import 'paciente.dart';

import 'horarios.dart';
import 'festivos.dart';

// 🔥 Firestore
import 'auth_store.dart';
import 'fire_appointments.dart';

class AgendarCitaScreen extends StatefulWidget {
  final Cita? citaParaEditar;
  const AgendarCitaScreen({super.key, this.citaParaEditar});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campos base
  String? _pacienteId;
  String _pacienteRespaldo = '';
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = const TimeOfDay(hour: 9, minute: 0);
  EstadoCita _estado = EstadoCita.pendiente;
  final _notasCtrl = TextEditingController();

  // ✅ duración en minutos
  int _duracionMin = 30;
  static const _duraciones = [15, 20, 30, 40, 45, 60, 90];

  bool get _editando => widget.citaParaEditar != null;

  @override
  void initState() {
    super.initState();

    final c = widget.citaParaEditar;
    if (c != null) {
      _pacienteId = c.pacienteId;
      _pacienteRespaldo = c.paciente;
      _fecha = DateTime(c.fechaHora.year, c.fechaHora.month, c.fechaHora.day);
      _hora = TimeOfDay(hour: c.fechaHora.hour, minute: c.fechaHora.minute);
      _estado = c.estado;
      _notasCtrl.text = c.notas;
      _duracionMin = c.duracionMin;
    } else {
      _fecha = DateTime.now();
      _hora = Horarios.inicio;
      _estado = EstadoCita.pendiente;
      _duracionMin = 30;
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  DateTime _toDateTime(DateTime date, TimeOfDay tod) {
    return DateTime(date.year, date.month, date.day, tod.hour, tod.minute);
  }

  bool _diaValido(DateTime d) => !Festivos.estaBloqueado(d);

  String _statusToStr(EstadoCita e) {
    switch (e) {
      case EstadoCita.pendiente:
        return 'pendiente';
      case EstadoCita.realizada:
        return 'realizada';
      case EstadoCita.cancelada:
        return 'cancelada';
    }
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Selecciona fecha',
    );

    if (picked == null) return;

    final solo = DateTime(picked.year, picked.month, picked.day);

    if (!_diaValido(solo)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Festivos.motivoBloqueo(solo))),
      );
      return;
    }

    setState(() => _fecha = solo);
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: 'Selecciona hora',
    );

    if (picked == null) return;

    if (!Horarios.permite(picked)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hora fuera de horario. Permitido: '
            '${Horarios.inicio.format(context)} - ${Horarios.fin.format(context)}',
          ),
        ),
      );
      return;
    }

    setState(() => _hora = picked);
  }

  Future<void> _agregarPacienteDesdeAgendar() async {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final notasCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo paciente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono (WhatsApp)'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }

    final nuevo = Paciente(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      telefono: telCtrl.text.trim(),
      notas: notasCtrl.text.trim(),
    );

    PacientesStore.pacientes.add(nuevo);
    await PersistenciaPacientes.guardar();

    setState(() {
      _pacienteId = nuevo.id;
      _pacienteRespaldo = nuevo.nombre;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paciente guardado ✅')),
    );
  }

  String _fechaTexto(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _guardarCita() async {
    if (!_formKey.currentState!.validate()) return;

    final fechaHora = _toDateTime(_fecha, _hora);

    final soloFecha = DateTime(fechaHora.year, fechaHora.month, fechaHora.day);
    if (!_diaValido(soloFecha)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Festivos.motivoBloqueo(soloFecha))),
      );
      return;
    }

    if (!Horarios.permite(_hora)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hora fuera de horario. Permitido: '
            '${Horarios.inicio.format(context)} - ${Horarios.fin.format(context)}',
          ),
        ),
      );
      return;
    }

    final p = PacientesStore.porId(_pacienteId ?? '');
    final nombreFinal = p?.nombre ?? _pacienteRespaldo;
    final telFinal = (p?.telefono ?? '').trim();

    if (nombreFinal.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un paciente o crea uno nuevo')),
      );
      return;
    }

    final clinicId = AuthStore.requireClinicId();
    final uid = AuthStore.uid.value ?? 'unknown';
    final email = AuthStore.email.value ?? '';

    String idParaNoti;

    if (_editando) {
      final c = widget.citaParaEditar!;

      // ===== Firestore update =====
      await FireAppointments.update(
        clinicId: clinicId,
        appointmentId: c.id,
        updatedByUid: uid,
        startAt: fechaHora,
        patientName: nombreFinal,
        patientId: _pacienteId,
        phone: telFinal,
        notes: _notasCtrl.text.trim(),
        durationMin: _duracionMin,
      );

      await FireAppointments.updateStatus(
        clinicId: clinicId,
        appointmentId: c.id,
        updatedByUid: uid,
        status: _statusToStr(_estado),
      );

      // ===== Local update =====
      c.pacienteId = _pacienteId;
      c.paciente = nombreFinal;
      c.fechaHora = fechaHora;
      c.estado = _estado;
      c.notas = _notasCtrl.text.trim();
      c.duracionMin = _duracionMin;

      // Si tu modelo aún tiene phone/service/motivo/pieza, no los tocamos.
      // Solo dejamos lo esencial.

      idParaNoti = c.id;
    } else {
      // ===== Crear en Firestore y usar ID =====
      final newId = await FireAppointments.create(
        clinicId: clinicId,
        createdByUid: uid,
        createdByEmail: email,
        startAt: fechaHora,
        patientName: nombreFinal,
        patientId: _pacienteId,
        phone: telFinal,
        notes: _notasCtrl.text.trim(),
        durationMin: _duracionMin,
      );

      await FireAppointments.updateStatus(
        clinicId: clinicId,
        appointmentId: newId,
        updatedByUid: uid,
        status: _statusToStr(_estado),
      );

      // ===== Local create =====
      final c = Cita(
        id: newId,
        paciente: nombreFinal,
        pacienteId: _pacienteId,
        fechaHora: fechaHora,
        estado: _estado,
        notas: _notasCtrl.text.trim(),
        duracionMin: _duracionMin,
      );
      CitasStore.citas.add(c);
      idParaNoti = c.id;
    }

    // Guardado local (si todavía lo usas)
    await PersistenciaCitas.guardar();

    // Notificaciones
    if (_estado == EstadoCita.pendiente && fechaHora.isAfter(DateTime.now())) {
      await Notificaciones.programar(
        id: idParaNoti,
        titulo: 'Cita médica',
        cuerpo: 'Cita con $nombreFinal',
        fechaHora: fechaHora,
      );
    } else {
      await Notificaciones.cancelar(idParaNoti);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final pacientes = PacientesStore.pacientes;
    final fechaHora = _toDateTime(_fecha, _hora);
    final bloqueado = Festivos.estaBloqueado(DateTime(_fecha.year, _fecha.month, _fecha.day));

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar cita' : 'Agendar cita'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: (_pacienteId != null && pacientes.any((p) => p.id == _pacienteId))
                          ? _pacienteId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Paciente',
                        border: OutlineInputBorder(),
                      ),
                      items: pacientes
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (id) {
                        setState(() {
                          _pacienteId = id;
                          final p = PacientesStore.porId(id ?? '');
                          _pacienteRespaldo = p?.nombre ?? '';
                        });
                      },
                      validator: (_) {
                        final p = PacientesStore.porId(_pacienteId ?? '');
                        final nombre = p?.nombre ?? _pacienteRespaldo;
                        if (nombre.trim().isEmpty) return 'Selecciona un paciente';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _agregarPacienteDesdeAgendar,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nuevo'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              value: _duracionMin,
              decoration: const InputDecoration(
                labelText: 'Duración de consulta',
                border: OutlineInputBorder(),
              ),
              items: _duraciones.map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _duracionMin = v);
              },
            ),

            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: Text('Fecha: ${_fechaTexto(_fecha)}'),
              subtitle: bloqueado
                  ? Text(Festivos.motivoBloqueo(_fecha), style: const TextStyle(color: Colors.red))
                  : null,
              trailing: OutlinedButton(
                onPressed: _pickFecha,
                child: const Text('Cambiar'),
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text('Hora: ${_hora.format(context)}'),
              subtitle: Text(
                'Horario permitido: ${Horarios.inicio.format(context)} - ${Horarios.fin.format(context)}',
              ),
              trailing: OutlinedButton(
                onPressed: _pickHora,
                child: const Text('Cambiar'),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<EstadoCita>(
              value: _estado,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: EstadoCita.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
              onChanged: (v) => setState(() => _estado = v ?? _estado),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _notasCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Motivo, indicaciones, etc.',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Resumen'),
                subtitle: Text(
                  'Fecha y hora: ${_fechaTexto(_fecha)} ${_hora.format(context)}\n'
                  'Duración: $_duracionMin min\n'
                  'Estado: ${_estado.name}\n'
                  'Notificación: ${(_estado == EstadoCita.pendiente && fechaHora.isAfter(DateTime.now())) ? "Sí" : "No"}',
                ),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _guardarCita,
              icon: const Icon(Icons.save),
              label: Text(_editando ? 'Guardar cambios' : 'Guardar cita'),
            ),
          ],
        ),
      ),
    );
  }
}