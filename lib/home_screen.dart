import 'package:flutter/material.dart';

import 'agendar_cita.dart';
import 'ver_citas.dart';
import 'calendario_screen.dart';
import 'pacientes_screen.dart';
import 'citas_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _go(Widget screen) async {
    final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (r == true) setState(() {});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = CitasStore.citas.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Citas Médicas'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Bienvenido a Citas Médicas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Agenda y administra tus citas fácilmente.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              SizedBox(
                width: 260,
                child: ElevatedButton.icon(
                  onPressed: () => _go(const AgendarCitaScreen()),
                  icon: const Icon(Icons.add),
                  label: const Text('Agendar cita'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: () => _go(const VerCitasScreen()),
                  icon: const Icon(Icons.list_alt),
                  label: Text('Ver mis citas ($total)'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: () => _go(const CalendarioScreen()),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Calendario'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: () => _go(const PacientesScreen()),
                  icon: const Icon(Icons.people),
                  label: const Text('Pacientes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}