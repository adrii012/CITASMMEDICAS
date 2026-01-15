import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// ✅ Alias para evitar choques de nombres
import 'persistencia.dart' as pcitas;
import 'persistencia_pacientes.dart' as ppac;

import 'notificaciones.dart';
import 'citas_store.dart';

import 'agendar_cita.dart';
import 'ver_citas.dart';
import 'calendario_screen.dart';
import 'pacientes_screen.dart';

import 'settings_store.dart';
import 'settings_screen.dart';
import 'estadisticas_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Ajustes (tema + colores)
  await SettingsStore.cargar();

  // ✅ Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Persistencia
  await pcitas.PersistenciaCitas.cargar();
  await ppac.PersistenciaPacientes.cargar();

  // ✅ Notificaciones (safe: web/desktop no rompe)
  await Notificaciones.inicializar();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha 3 cosas a la vez: themeMode, accentColor, backgroundColor
    return AnimatedBuilder(
      animation: Listenable.merge([
        SettingsStore.themeMode,
        SettingsStore.accentColor,
        SettingsStore.backgroundColor,
      ]),
      builder: (_, __) {
        final mode = SettingsStore.themeMode.value;
        final accent = SettingsStore.accentColor.value;
        final bg = SettingsStore.backgroundColor.value;

        final light = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light),
          brightness: Brightness.light,
          scaffoldBackgroundColor: bg,
        );

        final dark = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
        );

        return MaterialApp(
          title: 'Citas Médicas',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _irAAgendar() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgendarCitaScreen()),
    );
    if (result == true) setState(() {});
  }

  Future<void> _irAVerCitas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerCitasScreen()),
    );
    setState(() {});
  }

  Future<void> _irACalendario() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalendarioScreen()),
    );
    setState(() {});
  }

  Future<void> _irAPacientes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PacientesScreen()),
    );
    setState(() {});
  }

  Future<void> _irAAjustes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    setState(() {});
  }

  Future<void> _irAEstadisticas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EstadisticasScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = CitasStore.citas.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas Médicas'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings),
            onPressed: _irAAjustes,
          ),
        ],
      ),
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
              Text(
                'Citas guardadas: $total',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: 280,
                child: ElevatedButton.icon(
                  onPressed: _irAAgendar,
                  icon: const Icon(Icons.add),
                  label: const Text('Agendar cita'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: 280,
                child: OutlinedButton.icon(
                  onPressed: _irAVerCitas,
                  icon: const Icon(Icons.list_alt),
                  label: Text('Ver mis citas ($total)'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: 280,
                child: OutlinedButton.icon(
                  onPressed: _irACalendario,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Calendario'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: 280,
                child: OutlinedButton.icon(
                  onPressed: _irAPacientes,
                  icon: const Icon(Icons.people),
                  label: const Text('Pacientes'),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ (1) Estadísticas agregado
              SizedBox(
                width: 280,
                child: OutlinedButton.icon(
                  onPressed: _irAEstadisticas,
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Estadísticas'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: 280,
                child: OutlinedButton.icon(
                  onPressed: _irAAjustes,
                  icon: const Icon(Icons.tune),
                  label: const Text('Ajustes (colores/tema)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}