// lib/main.dart
import 'package:flutter/material.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'package:citas_medicas/notificaciones.dart';
import 'package:citas_medicas/auth_store.dart';
import 'package:citas_medicas/settings_store.dart';
import 'package:citas_medicas/fire_clinic_users.dart';

// Stores/data
import 'package:citas_medicas/citas_store.dart';
import 'package:citas_medicas/pacientes_store.dart';
import 'package:citas_medicas/almacen_store.dart';
import 'package:citas_medicas/historias_store.dart';

// Persistencias locales (si todavía las usas en partes)
import 'package:citas_medicas/persistencia.dart' as pcitas;
import 'package:citas_medicas/persistencia_pacientes.dart' as ppac;
import 'package:citas_medicas/persistencia_almacen.dart' as palmacen;
import 'package:citas_medicas/persistencia_historias.dart';

// Screens
import 'package:citas_medicas/login_screen.dart' as auth;
import 'package:citas_medicas/settings_screen.dart';
import 'package:citas_medicas/agendar_cita.dart';
import 'package:citas_medicas/ver_citas.dart';
import 'package:citas_medicas/calendario_screen.dart';
import 'package:citas_medicas/pacientes_screen.dart';
import 'package:citas_medicas/almacen_screen.dart';
import 'package:citas_medicas/historias_screen.dart';
import 'package:citas_medicas/estadisticas_screen.dart';
import 'package:citas_medicas/respaldos_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ NUEVO: handler FCM en background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const AppBoot());
}

/// ===================
/// BOOT
/// ===================
class AppBoot extends StatefulWidget {
  const AppBoot({super.key});

  @override
  State<AppBoot> createState() => _AppBootState();
}

class _AppBootState extends State<AppBoot> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initAll();
  }

  Future<void> _initMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    final currentClinicId = AuthStore.clinicId.value;
    final currentUid = AuthStore.uid.value;

    if (currentClinicId != null && currentUid != null) {
      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await FireClinicUsers.addFcmToken(
          clinicId: currentClinicId,
          uid: currentUid,
          token: token,
        );
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final clinicId = AuthStore.clinicId.value;
      final uid = AuthStore.uid.value;
      if (clinicId == null || uid == null) return;

      await FireClinicUsers.addFcmToken(
        clinicId: clinicId,
        uid: uid,
        token: token,
      );
    });
  }

  Future<void> _initAll() async {
    await SettingsStore.cargar();

    try {
      await Notificaciones.inicializar();
    } catch (_) {}

    await AuthStore.cargar();

    // ✅ NUEVO: inicializar FCM
    try {
      await _initMessaging();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return const MyApp();
      },
    );
  }
}

/// ===================
/// APP
/// ===================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme({
    required Brightness brightness,
    required Color accent,
    required Color bg,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: bg,

      iconTheme: IconThemeData(color: accent, size: 22),
      appBarTheme: const AppBarTheme(centerTitle: true),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          elevation: 2,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      ]),
      builder: (_, __) {
        final mode = SettingsStore.themeMode.value;
        final accent = SettingsStore.accentColor.value;
        final bg = SettingsStore.backgroundColor.value;

        return MaterialApp(
          title: 'Citas Médicas',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(brightness: Brightness.light, accent: accent, bg: bg),
          darkTheme: _buildTheme(brightness: Brightness.dark, accent: accent, bg: bg),
          themeMode: mode,
          home: const SessionGate(),
        );
      },
    );
  }
}

/// ===================
/// SESSION GATE (SOLO AUTH)
/// ===================
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _sync();
    AuthStore.isLogged.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthStore.isLogged.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _sync();
    if (mounted) setState(() {});
  }

  void _sync() {
    if (AuthStore.isLogged.value) {
      _loadFuture = _loadClinicData();
    } else {
      _loadFuture = null;
      CitasStore.citas.clear();
      PacientesStore.pacientes.clear();
      AlmacenStore.clear();
      HistoriasStore.clear();
    }
  }

  Future<void> _loadClinicData() async {
    // Si sigues usando partes locales, carga aquí
    await ppac.PersistenciaPacientes.cargar();
    await pcitas.PersistenciaCitas.cargar();
    await palmacen.PersistenciaAlmacen.cargar();
    AlmacenStore.recomputeLowStock();
    await PersistenciaHistorias.cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthStore.isLogged.value) {
      return const auth.LoginScreen();
    }

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ✅ SIN BLOQUEO LOCAL: SOLO FIREBASE RULES DECIDEN
        return const HomeScreen();
      },
    );
  }
}

/// ===================
/// HOME
/// ===================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _go(Widget screen) async {
    final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
    if (r == true && mounted) setState(() {});
  }

  Future<void> _logout() async {
    await AuthStore.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión cerrada ✅')),
    );
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
      width: 340,
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
    final totalCitas = CitasStore.citas.length;
    final totalPac = PacientesStore.pacientes.length;
    final totalItems = AlmacenStore.items.length;
    final totalHistorias = HistoriasStore.historias.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas Médicas'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _go(const SettingsScreen()),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
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
                'Bienvenido (${AuthStore.role.value})',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text('Clínica ID: ${AuthStore.clinicId.value ?? '-'}', textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Citas: $totalCitas • Pacientes: $totalPac • Almacén: $totalItems • Historias: $totalHistorias',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              _btn(
                onTap: () => _go(const AgendarCitaScreen()),
                icon: Icons.event_available_rounded,
                text: 'Agendar cita',
                primary: true,
              ),
              const SizedBox(height: 10),
              _btn(
                onTap: () => _go(const VerCitasScreen()),
                icon: Icons.list_alt_rounded,
                text: 'Ver mis citas ($totalCitas)',
              ),
              const SizedBox(height: 10),
              _btn(
                onTap: () => _go(const CalendarioScreen()),
                icon: Icons.calendar_month_rounded,
                text: 'Calendario',
              ),
              const SizedBox(height: 10),
              _btn(
                onTap: () => _go(const PacientesScreen()),
                icon: Icons.people_alt_rounded,
                text: 'Pacientes ($totalPac)',
              ),
              const SizedBox(height: 10),
              _btn(
                onTap: () => _go(const HistoriasScreen()),
                icon: Icons.medical_information_rounded,
                text: 'Historias clínicas ($totalHistorias)',
              ),
              const SizedBox(height: 10),
              _btn(
                onTap: () => _go(const EstadisticasScreen()),
                icon: Icons.bar_chart_rounded,
                text: 'Estadísticas',
              ),
              const SizedBox(height: 10),
              _btn(
                onTap: () => _go(const RespaldosScreen()),
                icon: Icons.cloud_upload_rounded,
                text: 'Respaldos',
              ),
              const SizedBox(height: 10),
              _btn(
                onTap: () => _go(const AlmacenScreen()),
                icon: Icons.inventory_2_rounded,
                text: 'Almacén ($totalItems)',
              ),
            ],
          ),
        ),
      ),
    );
  }
}