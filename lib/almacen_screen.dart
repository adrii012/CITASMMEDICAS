// lib/almacen_screen.dart
import 'package:flutter/material.dart';

import 'almacen_store.dart';
import 'almacen_item.dart';
import 'persistencia_almacen.dart';
import 'auth_store.dart';

class AlmacenScreen extends StatefulWidget {
  const AlmacenScreen({super.key});

  @override
  State<AlmacenScreen> createState() => _AlmacenScreenState();
}

class _AlmacenScreenState extends State<AlmacenScreen> {
  bool _loading = true;
  bool _soloBajos = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await PersistenciaAlmacen.cargar();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await PersistenciaAlmacen.guardar();
  }

  void _needAdmin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solo ADMIN puede hacer eso 🔒')),
    );
  }

  Future<void> _nuevoItem() async {
    if (!AuthStore.isAdmin) {
      _needAdmin();
      return;
    }

    final nombreCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final minCtrl = TextEditingController(text: '5');
    final notasCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock inicial',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mínimo (alerta BAJO)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notasCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: OutlineInputBorder(),
                ),
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

    final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
    final min = int.tryParse(minCtrl.text.trim()) ?? 5;

    final item = AlmacenItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      stock: stock < 0 ? 0 : stock,
      minStock: min < 0 ? 0 : min,
      notas: notasCtrl.text.trim(),
    );

    setState(() {
      AlmacenStore.add(item); // ✅ recalcula badge low stock
    });

    await _save();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item agregado ✅')),
    );
  }

  Future<void> _ajustarStock(AlmacenItem it, int delta) async {
    setState(() => AlmacenStore.ajustarStock(it.id, delta));
    await _save();
  }

  Future<void> _eliminar(AlmacenItem it) async {
    if (!AuthStore.isAdmin) {
      _needAdmin();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "${it.nombre}"?'),
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

    setState(() => AlmacenStore.eliminar(it.id));
    await _save();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eliminado 🗑️')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthStore.isAdmin;

    final all = AlmacenStore.items;
    final items = _soloBajos ? all.where((x) => x.isLow).toList() : all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Almacén'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: _soloBajos ? 'Ver todo' : 'Solo stock bajo',
            icon: Icon(_soloBajos ? Icons.filter_alt_off : Icons.warning_amber),
            onPressed: () => setState(() => _soloBajos = !_soloBajos),
          ),
          if (isAdmin)
            IconButton(
              tooltip: 'Agregar',
              icon: const Icon(Icons.add),
              onPressed: _nuevoItem,
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _nuevoItem,
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : all.isEmpty
              ? const Center(child: Text('No hay items en almacén'))
              : items.isEmpty
                  ? const Center(child: Text('No hay items en “stock bajo”'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final it = items[i];

                        final badge = it.isLow
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(),
                                ),
                                child: const Text(
                                  'BAJO',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              )
                            : null;

                        return Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(it.nombre)),
                                if (badge != null) ...[
                                  const SizedBox(width: 10),
                                  badge,
                                ],
                              ],
                            ),
                            subtitle: Text(
                              'Stock: ${it.stock}  (mín: ${it.minStock})\n${it.notas.isEmpty ? "(sin notas)" : it.notas}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  tooltip: '-1',
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => _ajustarStock(it, -1),
                                ),
                                IconButton(
                                  tooltip: '+1',
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _ajustarStock(it, 1),
                                ),
                                if (isAdmin)
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _eliminar(it),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}