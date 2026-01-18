// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'clinic_store.dart';
import 'auth_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<Clinic> _clinics = [];
  Clinic? _selectedClinic;

  final _clinicNameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _creatingClinic = false;

  // ✅ permitir crear clínica aunque ya existan
  bool _showCreateNewClinic = false;

  static const _templates = <String>[
    'Clínica General',
    'Ginecología',
    'Trauma / Ortopedia',
    'Medicina Interna',
    'Odontología (Dentista)',
    'Pediatría',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _clinics = await ClinicStore.cargarClinics();
    if (_clinics.isNotEmpty) _selectedClinic = _clinics.first;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clinicNameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _useTemplate(String name) {
    _clinicNameCtrl.text = name;
    setState(() => _showCreateNewClinic = true);

    if (_userCtrl.text.trim().isEmpty) {
      final lower = name.toLowerCase();
      if (lower.contains('gine')) _userCtrl.text = 'gine';
      else if (lower.contains('trauma')) _userCtrl.text = 'trauma';
      else if (lower.contains('interna')) _userCtrl.text = 'mi';
      else if (lower.contains('odonto') || lower.contains('dent')) _userCtrl.text = 'dental';
      else if (lower.contains('pedi')) _userCtrl.text = 'pediatria';
      else _userCtrl.text = 'general';
    }
  }

  Future<void> _createClinicAndAdmin() async {
    final name = _clinicNameCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    if (name.isEmpty || user.isEmpty || pass.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa clínica, usuario y contraseña')),
      );
      return;
    }

    setState(() => _creatingClinic = true);

    try {
      final clinics = await ClinicStore.cargarClinics();

      final exists = clinics.any((c) => c.name.trim().toLowerCase() == name.toLowerCase());
      if (exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya existe una clínica con ese nombre')),
        );
        return;
      }

      final clinicId = 'cli_${DateTime.now().millisecondsSinceEpoch}';
      final adminId = 'usr_${DateTime.now().microsecondsSinceEpoch}';

      final admin = ClinicStore.createUser(
        id: adminId,
        username: user,
        password: pass,
        role: 'admin',
      );

      final clinic = Clinic(id: clinicId, name: name, users: [admin]);
      clinics.add(clinic);
      await ClinicStore.guardarClinics(clinics);

      // ✅ guardamos rol admin en AuthStore
      await AuthStore.login(
        clinicIdValue: clinicId,
        userIdValue: adminId,
        roleValue: 'admin',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _creatingClinic = false);
    }
  }

  Future<void> _loginExisting() async {
    final clinic = _selectedClinic;
    if (clinic == null) return;

    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    if (user.isEmpty || pass.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe usuario y contraseña')),
      );
      return;
    }

    final found = clinic.users
        .where((u) => u.username.toLowerCase() == user.toLowerCase())
        .toList();

    if (found.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no existe en esta clínica')),
      );
      return;
    }

    final u = found.first;
    final ok = ClinicStore.verifyUser(u, pass);

    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña incorrecta')),
      );
      return;
    }

    // ✅ guardamos el rol real del usuario
    await AuthStore.login(
      clinicIdValue: clinic.id,
      userIdValue: u.id,
      roleValue: u.role,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasClinics = _clinics.isNotEmpty;
    final createMode = (!hasClinics) || _showCreateNewClinic;

    return Scaffold(
      appBar: AppBar(title: const Text('Acceso a la clínica')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasClinics) ...[
            const Text(
              'Primera vez: crea tu clínica y tu usuario administrador.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const Text(
              'Entrar a clínica existente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Clinic>(
              value: _selectedClinic,
              items: _clinics
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedClinic = v),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _showCreateNewClinic,
              onChanged: (v) => setState(() => _showCreateNewClinic = v),
              title: const Text('Crear nueva clínica'),
              subtitle: const Text('Útil para agregar Dentista, Pediatría, etc.'),
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plantillas rápidas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _templates.map((t) {
                        return OutlinedButton(
                          onPressed: () => _useTemplate(t),
                          child: Text(t),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (createMode) ...[
            const Text(
              'Nueva clínica',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clinicNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la clínica',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _creatingClinic
                ? null
                : (createMode ? _createClinicAndAdmin : _loginExisting),
            icon: const Icon(Icons.login),
            label: Text(createMode ? 'Crear clínica y entrar' : 'Entrar'),
          ),
        ],
      ),
    );
  }
}