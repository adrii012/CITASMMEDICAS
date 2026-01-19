import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:citas_medicas/firebase_options.dart';

// Persistencias (alias)
import 'package:citas_medicas/persistencia.dart' as pcitas;
import 'package:citas_medicas/persistencia_pacientes.dart' as ppac;
import 'package:citas_medicas/persistencia_almacen.dart' as palmacen;

import 'package:citas_medicas/notificaciones.dart';
import 'package:citas_medicas/citas_store.dart';
import 'package:citas_medicas/pacientes_store.dart';
import 'package:citas_medicas/almacen_store.dart';

import 'package:citas_medicas/agendar_cita.dart';
import 'package:citas_medicas/ver_citas.dart';
import 'package:citas_medicas/calendario_screen.dart';
import 'package:citas_medicas/pacientes_screen.dart';
import 'package:citas_medicas/almacen_screen.dart';

import 'package:citas_medicas/settings_store.dart';
import 'package:citas_medicas/settings_screen.dart';
import 'package:citas_medicas/estadisticas_screen.dart';
import 'package:citas_medicas/respaldos_screen.dart';

import 'package:citas_medicas/license_store.dart';

// 👇 Import con alias para evitar choques de nombres (blindaje total)
import 'package:citas_medicas/locked_screen.dart' as locked;
import 'package:citas_medicas/login_screen.dart' as auth;

import 'package:citas_medicas/auth_store.dart';

// ✅ Historias clínicas
import 'package:citas_medicas/historias_screen.dart';
import 'package:citas_medicas/persistencia_historias.dart';
import 'package:citas_medicas/historias_store.dart';

// ✅ Licencia remota (Firestore)
import 'package:citas_medicas/remote_license_service.dart';

void main() {
  // ✅ CLAVE en Web: NO esperar init antes de pintar algo
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBoot());
}

/// ✅ Arranca UI YA, y mientras tanto inicializa todo en segundo plano
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

  Future<void> _initAll() async {
    // Settings primero (para tema/colores)
    await SettingsStore.cargar();

    // Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Notificaciones: en Web puede fallar dependiendo del navegador/permisos
    // Si truena aquí, te deja pantalla negra. Lo blindamos.
    try {
      await Notificaciones.inicializar();
    } catch (_) {
      // En web o PCs sin permisos, lo ignoramos.
    }

    await AuthStore.cargar();
    await LicenseStore.cargar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootSplash(),
          );
        }

        // Si hubo error real, lo mostramos (mejor que negro)
        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _BootError(error: snap.error),
          );
        }

        return const MyApp();
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(),
            ),
            SizedBox(height: 14),
            Text('Cargando plataforma…'),
          ],
        ),
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  final Object? error;
  const _BootError({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 10),
              const Text(
                'Error al iniciar la app',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'Error desconocido',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AppBoot()),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper para revalidar licencia al volver del fondo
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ valida remoto si hay sesión, si no, usa local
  Future<void> _validarLicencia() async {
    // Siempre refresca local (trial fallback)
    await LicenseStore.validar();

    // Si NO hay login, no hacemos Firestore
    if (!AuthStore.isLogged.value) return;

    try {
      final clinicId = AuthStore.requireClinicIdOr('clinic_demo');
      await RemoteLicenseService.syncFromFirestore(clinicId: clinicId);
    } catch (_) {
      // nos quedamos con local
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validarLicencia();
    }
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

        final light = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.light,
          ),
          brightness: Brightness.light,
          scaffoldBackgroundColor: bg,
        );

        final dark = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ),
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
        );

        return MaterialApp(
          title: 'Citas Médicas',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          home: const SessionGate(),
        );
      },
    );
  }
}

/// Decide: Login vs App
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  Future<void>? _loadAfterLoginFuture;

  @override
  void initState() {
    super.initState();
    _syncFuture();

    AuthStore.isLogged.addListener(_onAuthChanged);
    LicenseStore.isLocked.addListener(_onLicenseChanged);
  }

  @override
  void dispose() {
    AuthStore.isLogged.removeListener(_onAuthChanged);
    LicenseStore.isLocked.removeListener(_onLicenseChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _syncFuture();
    if (mounted) setState(() {});
  }

  void _onLicenseChanged() {
    if (mounted) setState(() {});
  }

  void _syncFuture() {
    if (AuthStore.isLogged.value) {
      _loadAfterLoginFuture = _loadClinicData();
    } else {
      _loadAfterLoginFuture = null;

      // ✅ detener listener remoto al cerrar sesión
      RemoteLicenseService.stopListener();

      CitasStore.citas.clear();
      PacientesStore.pacientes.clear();
      AlmacenStore.clear();

      // ✅ limpiar historias en memoria al cerrar sesión
      HistoriasStore.clear();

      // ✅ opcional: limpiar info remota (solo UI)
      LicenseStore.clearRemoteInfo();
    }
  }

  Future<void> _loadClinicData() async {
    await ppac.PersistenciaPacientes.cargar();
    await pcitas.PersistenciaCitas.cargar();
    await palmacen.PersistenciaAlmacen.cargar();

    AlmacenStore.recomputeLowStock();

    await PersistenciaHistorias.cargar();

    // ✅ primero local (trial)
    await LicenseStore.validar();

    // ✅ luego arrancar listener remoto EN VIVO
    try {
      final clinicId = AuthStore.requireClinicIdOr('clinic_demo');
      await RemoteLicenseService.startListener(clinicId: clinicId);
    } catch (_) {
      // si falla, nos quedamos con local
    }
  }

  @override
  Widget build(BuildContext context) {
    final logged = AuthStore.isLogged.value;

    if (!logged) {
      return const auth.LoginScreen();
    }

    return FutureBuilder<void>(
      future: _loadAfterLoginFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final lockedNow = LicenseStore.isLocked.value;
        return lockedNow ? const locked.LockedScreen() : const HomeScreen();
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

  Future<void> _irAEstadisticas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EstadisticasScreen()),
    );
  }

  Future<void> _irARespaldos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RespaldosScreen()),
    );
  }

  Future<void> _irAAlmacen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlmacenScreen()),
    );
    setState(() {});
  }

  Future<void> _irAHistorias() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoriasScreen()),
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

  Future<void> _logout() async {
    // ✅ parar listener remoto antes de salir
    RemoteLicenseService.stopListener();

    await AuthStore.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión cerrada ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCitas = CitasStore.citas.length;
    final totalPac = PacientesStore.pacientes.length;
    final totalItems = AlmacenStore.items.length;
    final totalHistorias = HistoriasStore.historias.length;

    Widget btn({
      required VoidCallback onTap,
      required IconData icon,
      required String text,
      bool primary = false,
    }) {
      final child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Flexible(child: Text(text, textAlign: TextAlign.center)),
        ],
      );

      return SizedBox(
        width: 320,
        child: primary
            ? ElevatedButton(
                onPressed: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: child,
                ),
              )
            : OutlinedButton(
                onPressed: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: child,
                ),
              ),
      );
    }

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
              const Icon(Icons.calendar_month, size: 80),
              const SizedBox(height: 12),
              Text(
                'Bienvenido (${AuthStore.role.value})',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Citas: $totalCitas • Pacientes: $totalPac • Almacén: $totalItems • Historias: $totalHistorias',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // ✅ útil: ver estado de licencia en Home (opcional)
              ValueListenableBuilder<String>(
                valueListenable: LicenseStore.reason,
                builder: (_, r, __) => Text(
                  r,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 18),

              btn(
                onTap: _irAAgendar,
                icon: Icons.add,
                text: 'Agendar cita',
                primary: true,
              ),
              const SizedBox(height: 10),

              btn(
                onTap: _irAVerCitas,
                icon: Icons.list_alt,
                text: 'Ver mis citas ($totalCitas)',
              ),
              const SizedBox(height: 10),

              btn(
                onTap: _irACalendario,
                icon: Icons.calendar_today,
                text: 'Calendario',
              ),
              const SizedBox(height: 10),

              btn(
                onTap: _irAPacientes,
                icon: Icons.people,
                text: 'Pacientes ($totalPac)',
              ),
              const SizedBox(height: 10),

              btn(
                onTap: _irAHistorias,
                icon: Icons.description,
                text: 'Historias clínicas ($totalHistorias)',
              ),
              const SizedBox(height: 10),

              btn(
                onTap: _irAEstadisticas,
                icon: Icons.bar_chart,
                text: 'Estadísticas',
              ),
              const SizedBox(height: 10),

              btn(
                onTap: _irARespaldos,
                icon: Icons.backup,
                text: 'Respaldos',
              ),
              const SizedBox(height: 10),

              ValueListenableBuilder<int>(
                valueListenable: AlmacenStore.lowStockCount,
                builder: (_, low, __) {
                  final extra = low > 0 ? '  ⚠️ $low bajo' : '';
                  return btn(
                    onTap: _irAAlmacen,
                    icon: Icons.inventory_2,
                    text: 'Almacén ($totalItems)$extra',
                  );
                },
              ),
              const SizedBox(height: 10),

              btn(
                onTap: _irAAjustes,
                icon: Icons.tune,
                text: 'Ajustes (colores/tema)',
              ),
            ],
          ),
        ),
      ),
    );
  }
}