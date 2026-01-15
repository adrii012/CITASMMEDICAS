import 'package:flutter/material.dart';

import 'pacientes_store.dart';
import 'persistencia_pacientes.dart';
import 'paciente.dart';
import 'citas_store.dart';

class PacientesScreen extends StatefulWidget {
  const PacientesScreen({super.key});

  @override
  State<PacientesScreen> createState() => _PacientesScreenState();
}

class _PacientesScreenState extends State<PacientesScreen> {
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
          ElevatedButton(
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

    PacientesStore.pacientes.add(
      Paciente(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        nombre: nombre,
        telefono: telCtrl.text.trim(),
        notas: notasCtrl.text.trim(),
      ),
    );

    await PersistenciaPacientes.guardar();

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pacientes = PacientesStore.pacientes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pacientes'),
        actions: [
          IconButton(
            tooltip: 'Agregar',
            icon: const Icon(Icons.person_add),
            onPressed: _nuevoPaciente,
          ),
        ],
      ),
      body: pacientes.isEmpty
          ? const Center(child: Text('No hay pacientes'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pacientes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = pacientes[i];
                final citasDePaciente =
                    CitasStore.citas.where((c) => c.pacienteId == p.id).length;

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(p.nombre),
                    subtitle: Text(
                      'Tel: ${p.telefono.isEmpty ? "-" : p.telefono}\nCitas: $citasDePaciente',
                    ),
                    isThreeLine: true,
                  ),
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