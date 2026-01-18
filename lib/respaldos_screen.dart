import 'package:flutter/material.dart';
import 'backup_service.dart';
import 'restore_log_store.dart';

class RespaldosScreen extends StatefulWidget {
  const RespaldosScreen({super.key});

  @override
  State<RespaldosScreen> createState() => _RespaldosScreenState();
}

class _RespaldosScreenState extends State<RespaldosScreen> {
  final _restoreCtrl = TextEditingController();

  bool _restoreLicense = true;
  bool _restoreSettings = true;
  bool _restorePacientes = true;
  bool _restoreCitas = true;

  List<RestoreLogEntry> _log = [];

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    _log = await RestoreLogStore.cargar();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _restoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _restaurar() async {
    final txt = _restoreCtrl.text.trim();

    if (!_restoreLicense && !_restoreSettings && !_restorePacientes && !_restoreCitas) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos 1 cosa para restaurar')),
      );
      return;
    }

    try {
      final result = await BackupService.restoreFromJsonString(
        context,
        txt,
        restoreLicense: _restoreLicense,
        restoreSettings: _restoreSettings,
        restorePacientes: _restorePacientes,
        restoreCitas: _restoreCitas,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Restauración exitosa ✅'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qué se restauró: ${result.restoredWhat}'),
              const SizedBox(height: 8),
              Text('Pacientes restaurados: ${result.pacientesCount}'),
              Text('Citas restauradas: ${result.citasCount}'),
              const SizedBox(height: 8),
              Text('Fecha del backup: ${result.backupTimestampIso.isEmpty ? "(sin timestamp)" : result.backupTimestampIso}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      await _loadLog();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado correctamente ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      await _loadLog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _copiarJson() async {
    await BackupService.copyBackupJsonToClipboard();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON copiado al portapapeles ✅')),
    );
  }

  Future<void> _guardarArchivo() async {
    final file = await BackupService.saveBackupFile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup guardado en: ${file.path} ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ✅ En PC el share puede no abrir nada, pero lo dejamos
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Compartir backup (Android/iOS)'),
              onPressed: () async => BackupService.shareBackup(context),
            ),
            const SizedBox(height: 10),

            // ✅ PC friendly
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copiar JSON del backup (PC)'),
              onPressed: _copiarJson,
            ),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Guardar backup como archivo .json (PC)'),
              onPressed: _guardarArchivo,
            ),

            const SizedBox(height: 18),
            const Text('Restauración selectiva', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            SwitchListTile(
              value: _restoreLicense,
              onChanged: (v) => setState(() => _restoreLicense = v),
              title: const Text('Licencia (trial/desbloqueo)'),
            ),
            SwitchListTile(
              value: _restoreSettings,
              onChanged: (v) => setState(() => _restoreSettings = v),
              title: const Text('Ajustes (tema/colores)'),
            ),
            SwitchListTile(
              value: _restorePacientes,
              onChanged: (v) => setState(() => _restorePacientes = v),
              title: const Text('Pacientes'),
            ),
            SwitchListTile(
              value: _restoreCitas,
              onChanged: (v) => setState(() => _restoreCitas = v),
              title: const Text('Citas'),
            ),

            const SizedBox(height: 10),
            const Text('Pega el JSON del respaldo', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            TextField(
              controller: _restoreCtrl,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: 'Pega aquí el JSON del respaldo…',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar'),
              onPressed: _restaurar,
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Log de restauraciones', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await RestoreLogStore.clear();
                    await _loadLog();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_log.isEmpty)
              const Text('Sin registros todavía.')
            else
              ..._log.map((e) {
                final okIcon = e.ok ? Icons.check_circle : Icons.error;
                final okText = e.ok ? 'Éxito' : 'Error';
                return Card(
                  child: ListTile(
                    leading: Icon(okIcon),
                    title: Text('$okText • ${e.restoredWhat}'),
                    subtitle: Text(
                      'Fecha: ${e.timestampIso}\n'
                      'Backup: ${e.fromBackupTimestampIso}\n'
                      'Pacientes: ${e.pacientesCount} • Citas: ${e.citasCount}\n'
                      '${e.message}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}