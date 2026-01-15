import 'package:flutter/material.dart';
import 'settings_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _colorDot({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            width: selected ? 4 : 2,
            color: selected ? Colors.white : Colors.black12,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white)
            : const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: SettingsStore.backgroundColor,
      builder: (_, bg, __) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(title: const Text('Ajustes')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Tema',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ValueListenableBuilder<ThemeMode>(
                valueListenable: SettingsStore.themeMode,
                builder: (_, mode, __) {
                  return Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        groupValue: mode,
                        title: const Text('Oscuro (default)'),
                        onChanged: (v) => SettingsStore.setTheme(v!),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        groupValue: mode,
                        title: const Text('Claro'),
                        onChanged: (v) => SettingsStore.setTheme(v!),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        groupValue: mode,
                        title: const Text('Sistema'),
                        onChanged: (v) => SettingsStore.setTheme(v!),
                      ),
                    ],
                  );
                },
              ),

              const Divider(height: 32),

              const Text('Color acento (botones)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              ValueListenableBuilder<Color>(
                valueListenable: SettingsStore.accentColor,
                builder: (_, selected, __) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: SettingsStore.accentPalette.map((c) {
                      return _colorDot(
                        color: c,
                        selected: c.value == selected.value,
                        onTap: () => SettingsStore.setAccent(c),
                      );
                    }).toList(),
                  );
                },
              ),

              const Divider(height: 32),

              const Text('Fondo (pantallas)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              ValueListenableBuilder<Color>(
                valueListenable: SettingsStore.backgroundColor,
                builder: (_, selected, __) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: SettingsStore.backgroundPalette.map((c) {
                      return _colorDot(
                        color: c,
                        selected: c.value == selected.value,
                        onTap: () => SettingsStore.setBackground(c),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () async {
                  await SettingsStore.setTheme(ThemeMode.dark);
                  await SettingsStore.setAccent(Colors.deepPurple);
                  await SettingsStore.setBackground(const Color(0xFF0B0F17));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ajustes restaurados')),
                    );
                  }
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restaurar por defecto'),
              ),
            ],
          ),
        );
      },
    );
  }
}