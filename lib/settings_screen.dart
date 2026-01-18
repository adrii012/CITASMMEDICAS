import 'package:flutter/material.dart';
import 'settings_store.dart';
import 'license_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openDevPanel(BuildContext context) async {
    final trialCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Panel DEV (oculto)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esto es solo para pruebas.\nLuego lo cambiamos por activación real.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: trialCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cambiar trial days (ej. 7)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await LicenseStore.resetTrial();
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trial reseteado ✅')),
                );
              }
            },
            child: const Text('Reset trial'),
          ),
          FilledButton(
            onPressed: () async {
              await LicenseStore.setUnlocked(true);
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Desbloqueado (DEV) ✅')),
                );
              }
            },
            child: const Text('Desbloquear (DEV)'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final v = int.tryParse(trialCtrl.text.trim());
              if (v != null && v > 0) {
                await LicenseStore.setTrialDays(v);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Trial days actualizado a $v ✅')),
                  );
                }
              }
            },
            child: const Text('Guardar trial'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        SettingsStore.themeMode,
        SettingsStore.accentColor,
        SettingsStore.backgroundColor,
        LicenseStore.isLocked,
        LicenseStore.daysLeft,
        LicenseStore.reason,
      ]),
      builder: (_, __) {
        final locked = LicenseStore.isLocked.value;
        final days = LicenseStore.daysLeft.value;
        final reason = LicenseStore.reason.value;

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onLongPress: () => _openDevPanel(context),
              child: const Text('Ajustes'),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(locked ? Icons.lock : Icons.verified),
                  title: Text(locked ? 'Licencia: BLOQUEADA' : 'Licencia: ACTIVA'),
                  subtitle: Text(
                    'Motivo/estado: $reason\nDías restantes: $days',
                  ),
                  trailing: IconButton(
                    tooltip: 'Revalidar',
                    icon: const Icon(Icons.refresh),
                    onPressed: () async => LicenseStore.validar(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Aquí puedes dejar tu UI real de colores/tema.
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Tema / Colores'),
                  subtitle: Text(
                    'Tema: ${SettingsStore.themeMode.value.name}\n'
                    'Acento: ${SettingsStore.accentColor.value.value}\n'
                    'Fondo: ${SettingsStore.backgroundColor.value.value}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}