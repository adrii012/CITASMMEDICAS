// lib/pacientes_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'paciente.dart';
import 'pacientes_store.dart';
import 'citas_store.dart';

import 'auth_store.dart';
import 'fire_patients.dart';

// Historias (por ahora siguen local)
import 'historias_screen.dart';
import 'historias_store.dart';
import 'persistencia_historias.dart';

class PacientesScreen extends StatefulWidget {
  const PacientesScreen({super.key});

  @override
  State<PacientesScreen> createState() => _PacientesScreenState();
}

class _PacientesScreenState extends State<PacientesScreen> {
  bool _loadingHistorias = false;

  @override
  void initState() {
    super.initState();
    _cargarHistoriasParaContadores();
  }

  Future<void> _cargarHistoriasParaContadores() async {
    if (_loadingHistorias) return;
    _loadingHistorias = true;
    try {
      await PersistenciaHistorias.cargar();
    } catch (_) {
      // no crashear
    } finally {
      _loadingHistorias = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _nuevoPaciente() async {
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
              const SizedBox(height: 8),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
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

    final clinicId = AuthStore.requireClinicId();
    final uid = AuthStore.uid.value ?? '';
    final email = AuthStore.email.value ?? '';

    try {
      await FirePatients.create(
        clinicId: clinicId,
        name: nombre,
        phone: telCtrl.text.trim(),
        notes: notasCtrl.text.trim(),
        createdByUid: uid.isEmpty ? 'unknown' : uid,
        createdByEmail: email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente guardado ✅')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar (Firestore): ${e.code}')),
      );
    }
  }

  Future<void> _verHistoriasPaciente(Paciente p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriasScreen(
          pacienteId: p.id,
          pacienteNombre: p.nombre,
        ),
      ),
    );

    await _cargarHistoriasParaContadores();
  }

  // Map Firestore -> Paciente
  Paciente _mapToPaciente(Map<String, dynamic> m) {
    return Paciente(
      id: (m['id'] ?? '').toString(),
      nombre: (m['name'] ?? '').toString(),
      telefono: (m['phone'] ?? '').toString(),
      notas: (m['notes'] ?? '').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = AuthStore.requireClinicId();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pacientes'),
        actions: [
          IconButton(
            tooltip: 'Recargar historias',
            icon: const Icon(Icons.refresh),
            onPressed: _cargarHistoriasParaContadores,
          ),
          IconButton(
            tooltip: 'Agregar',
            icon: const Icon(Icons.person_add),
            onPressed: _nuevoPaciente,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirePatients.streamAll(clinicId: clinicId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final rows = snap.data ?? const [];
          final pacientes = rows.map(_mapToPaciente).where((p) => p.id.isNotEmpty).toList();

          // ✅ Mantener el store local actualizado para que otras pantallas (citas/historias) sigan funcionando
          PacientesStore.pacientes
            ..clear()
            ..addAll(pacientes);

          if (pacientes.isEmpty) {
            return const Center(child: Text('No hay pacientes'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pacientes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = pacientes[i];

              final citasDePaciente = CitasStore.citas.where((c) => c.pacienteId == p.id).length;
              final historiasDePaciente = HistoriasStore.historias.where((h) => h.pacienteId == p.id).length;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(p.nombre),
                  subtitle: Text(
                    'Tel: ${p.telefono.isEmpty ? "-" : p.telefono}\n'
                    'Citas: $citasDePaciente • Historias: $historiasDePaciente',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Historias clínicas',
                        icon: const Icon(Icons.folder_shared),
                        onPressed: () => _verHistoriasPaciente(p),
                      ),
                    ],
                  ),
                  onTap: () => _verHistoriasPaciente(p),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoPaciente,
        child: const Icon(Icons.add),
      ),
    );
  }
}