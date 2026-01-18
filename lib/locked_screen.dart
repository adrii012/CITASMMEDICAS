// lib/locked_screen.dart
import 'package:flutter/material.dart';
import 'license_store.dart';

class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Licencia requerida'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 72),
              const SizedBox(height: 12),
              const Text(
                'La app está bloqueada por licencia.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Activa o renueva la licencia para continuar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await LicenseStore.validar();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar validación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}