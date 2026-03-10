// lib/locked_screen.dart
import 'package:flutter/material.dart';
import 'package:citas_medicas/license_store.dart';

class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App bloqueada'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 70),
              const SizedBox(height: 14),
              const Text(
                'Acceso bloqueado',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<String>(
                valueListenable: LicenseStore.reason,
                builder: (_, reason, __) => Text(
                  reason,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<int>(
                valueListenable: LicenseStore.daysLeft,
                builder: (_, days, __) => Text(
                  'Días restantes: $days',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  // Revalidar manualmente
                  await LicenseStore.validar();
                  // La pantalla se actualizará sola por los ValueListenableBuilder
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Revalidar licencia'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
