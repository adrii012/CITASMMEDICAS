// lib/historias_screen.dart
import 'package:flutter/material.dart';

import 'pacientes_store.dart';
import 'paciente.dart';

import 'historias_store.dart';
import 'persistencia_historias.dart';
import 'historia_clinica.dart';
import 'historia_editor_screen.dart';

class HistoriasScreen extends StatefulWidget {
  // ✅ Si lo mandas, se fija el paciente y no muestra dropdown
  final String? pacienteId;
  final String? pacienteNombre;

  const HistoriasScreen({
    super.key,
    this.pacienteId,
    this.pacienteNombre,
  });

  @override
  State<HistoriasScreen> createState() => _HistoriasScreenState();
}

class _HistoriasScreenState extends State<HistoriasScreen> {
  bool _loading = true;
  Paciente? _selectedPaciente;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await PersistenciaHistorias.cargar();

    if (!mounted) return;

    final pacs = PacientesStore.pacientes;

    // ✅ Si viene pacienteId, seleccionar ese
    if (widget.pacienteId != null && widget.pacienteId!.trim().isNotEmpty) {
      _selectedPaciente = PacientesStore.porId(widget.pacienteId);
    }

    // ✅ Si no viene pacienteId, seleccionar primero si hay
    if (_selectedPaciente == null && pacs.isNotEmpty) {
      _selectedPaciente = pacs.first;
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await PersistenciaHistorias.guardar();
  }

  Future<HistoriaTipo?> _pickTipo() async {
    return showDialog<HistoriaTipo>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Tipo de historia'),
        children: HistoriasStore.tipos.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, e.key),
            child: Text(e.value),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _crearNueva() async {
    final pac = _selectedPaciente;
    if (pac == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero crea/elige un paciente')),
      );
      return;
    }

    final tipo = await _pickTipo();
    if (tipo == null) return;

    final h = HistoriaClinica(
      id: 'his_${DateTime.now().microsecondsSinceEpoch}',
      pacienteId: pac.id,
      createdAt: DateTime.now(),
      tipo: tipo,
      secciones: HistoriaClinica.plantilla(tipo),
    );

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriaEditorScreen(historia: h),
      ),
    );

    if (ok == true) {
      HistoriasStore.upsert(h);
      await _save();
      if (mounted) setState(() {});
    }
  }

  Future<void> _editar(HistoriaClinica h) async {
    final copy = HistoriaClinica.fromJson(h.toJson()); // clon rápido

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriaEditorScreen(historia: copy),
      ),
    );

    if (ok == true) {
      HistoriasStore.upsert(copy);
      await _save();
      if (mounted) setState(() {});
    }
  }

  Future<void> _eliminar(HistoriaClinica h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar esta historia clínica?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    HistoriasStore.eliminar(h.id);
    await _save();
    if (mounted) setState(() {});
  }

  String _hh(String v) => (v.trim().isEmpty) ? '--:--' : v.trim();

  @override
  Widget build(BuildContext context) {
    final pacs = PacientesStore.pacientes;

    final pac = _selectedPaciente;
    final historias =
        (pac == null) ? <HistoriaClinica>[] : HistoriasStore.porPaciente(pac.id);

    final lockedPaciente =
        widget.pacienteId != null && widget.pacienteId!.trim().isNotEmpty;

    final title = lockedPaciente
        ? 'Historias • ${widget.pacienteNombre ?? (pac?.nombre ?? '')}'
        : 'Historias clínicas';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Nueva',
            icon: const Icon(Icons.add),
            onPressed: _crearNueva,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearNueva,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (pacs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No hay pacientes. Crea pacientes primero para hacer historias clínicas.',
                      ),
                    )
                  else if (!lockedPaciente)
                    DropdownButtonFormField<Paciente>(
                      value: pac,
                      items: pacs
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.nombre),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPaciente = v),
                      decoration: const InputDecoration(
                        labelText: 'Paciente',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    // ✅ Modo “fijo por paciente”
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Paciente: ${widget.pacienteNombre ?? (pac?.nombre ?? "-")}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: historias.isEmpty
                        ? const Center(
                            child: Text('No hay historias para este paciente'),
                          )
                        : ListView.separated(
                            itemCount: historias.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final h = historias[i];
                              final tipoLabel =
                                  HistoriasStore.tipos[h.tipo] ?? h.tipo.name;

                              return Card(
                                child: ListTile(
                                  title: Text(tipoLabel),
                                  subtitle: Text(
                                    'Entrada: ${_hh(h.horaEntrada)}  •  Salida: ${_hh(h.horaSalida)}',
                                  ),
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editar(h),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _eliminar(h),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _editar(h),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}