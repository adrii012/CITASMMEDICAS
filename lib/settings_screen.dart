// lib/settings_screen.dart
import 'package:flutter/material.dart';

import 'settings_store.dart';
import 'auth_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        SettingsStore.themeMode,
        SettingsStore.accentColor,
        SettingsStore.backgroundColor,
      ]),
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ajustes'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_rounded),
                  title: const Text('Tema / Colores'),
                  subtitle: Text(
                    'Tema: ${SettingsStore.themeMode.value.name}\n'
                    'Color acento: ${SettingsStore.accentColor.value.value}\n'
                    'Color fondo: ${SettingsStore.backgroundColor.value.value}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Cerrar sesión'),
                  onTap: () async {
                    await AuthStore.logout();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sesión cerrada ✅')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}