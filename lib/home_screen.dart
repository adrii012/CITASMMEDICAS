// lib/home_screen.dart
import 'package:flutter/material.dart';

import 'agendar_cita.dart';
import 'ver_citas.dart';
import 'calendario_screen.dart';
import 'pacientes_screen.dart';
import 'settings_screen.dart';

import 'citas_store.dart';
import 'auth_store.dart';
import 'settings_store.dart';

// ✅ Nuevo
import 'admin_users_screen.dart';

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

  Future<void> _logout() async {
    await AuthStore.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión cerrada ✅')));
  }

  Widget _brandMark() {
    final accent = SettingsStore.accentColor.value;
    return Center(
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.90), accent.withOpacity(0.35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.local_hospital_rounded, size: 44, color: Colors.white),
        ),
      ),
    );
  }

  Widget _btn({
    required VoidCallback onTap,
    required IconData icon,
    required String text,
    bool primary = false,
  }) {
    return SizedBox(
      width: 360,
      child: primary
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(text, textAlign: TextAlign.center),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(text, textAlign: TextAlign.center),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = CitasStore.citas.length;
    final role = AuthStore.role.value;
    final clinicId = AuthStore.clinicId.value ?? '-';
    final email = AuthStore.email.value ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas Médicas'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings),
            onPressed: () => _go(const SettingsScreen()),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            shrinkWrap: true,
            children: [
              _brandMark(),
              const SizedBox(height: 12),
              Text(
                'Bienvenido ($role)',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text('Clínica: $clinicId', textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(email, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text('Citas: $total', textAlign: TextAlign.center),
              const SizedBox(height: 18),

              _btn(onTap: () => _go(const AgendarCitaScreen()), icon: Icons.event_available_rounded, text: 'Agendar cita', primary: true),
              const SizedBox(height: 10),
              _btn(onTap: () => _go(const VerCitasScreen()), icon: Icons.list_alt_rounded, text: 'Ver mis citas ($total)'),
              const SizedBox(height: 10),
              _btn(onTap: () => _go(const CalendarioScreen()), icon: Icons.calendar_month_rounded, text: 'Calendario'),
              const SizedBox(height: 10),
              _btn(onTap: () => _go(const PacientesScreen()), icon: Icons.people_alt_rounded, text: 'Pacientes'),
              const SizedBox(height: 16),

              if (AuthStore.isAdmin) ...[
                const Divider(),
                const SizedBox(height: 6),
                _btn(
                  onTap: () => _go(const AdminUsersScreen()),
                  icon: Icons.admin_panel_settings_rounded,
                  text: 'Usuarios (solo admin)',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
