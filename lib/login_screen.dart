import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:citas_medicas/auth_store.dart';
import 'package:citas_medicas/fire_clinic_users.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _clinicIdCtrl = TextEditingController();
  final _clinicNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _createMode = false;

  @override
  void dispose() {
    _clinicIdCtrl.dispose();
    _clinicNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  String _normEmail(String e) => e.trim().toLowerCase();

  Future<void> _crearClinicaYAdmin() async {
    final clinicId = _clinicIdCtrl.text.trim();
    final clinicName = _clinicNameCtrl.text.trim();
    final email = _normEmail(_emailCtrl.text);
    final pass = _passCtrl.text;

    if (clinicId.isEmpty || clinicName.isEmpty || email.isEmpty || pass.isEmpty) {
      _snack('Completa Clinic ID, nombre, correo y contraseña');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final user = cred.user;
      if (user == null) throw Exception('No se pudo crear usuario');

      await FireClinicUsers.ensureClinic(
        clinicId: clinicId,
        clinicName: clinicName,
        ownerUid: user.uid,
        ownerEmail: email,
      );

      await FireClinicUsers.ensureUser(
        clinicId: clinicId,
        uid: user.uid,
        email: email,
        role: 'admin',
        active: true,
      );

      final info = await FireClinicUsers.getRoleForClinic(
        clinicId: clinicId,
        uid: user.uid,
      );

      if (!info.active) {
        await _auth.signOut();
        throw Exception('Usuario desactivado para esta clínica');
      }

      await AuthStore.login(
        clinicIdValue: clinicId,
        uidValue: user.uid,
        roleValue: info.role,
        emailValue: email,
      );

      // ✅ NO Navigator.pop(); Login es la pantalla raíz.
      // SessionGate detecta AuthStore.isLogged y cambia a Home automáticamente.
      if (!mounted) return;
      _snack('Acceso correcto ✅');
      return;
    } on FirebaseAuthException catch (e) {
      _snack(_authError(e));
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _entrar() async {
    final clinicId = _clinicIdCtrl.text.trim();
    final email = _normEmail(_emailCtrl.text);
    final pass = _passCtrl.text;

    if (clinicId.isEmpty || email.isEmpty || pass.isEmpty) {
      _snack('Completa Clinic ID, correo y contraseña');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final user = cred.user;
      if (user == null) throw Exception('No se pudo iniciar sesión');

      final info = await FireClinicUsers.getRoleForClinic(
        clinicId: clinicId,
        uid: user.uid,
      );

      if (!info.active) {
        await _auth.signOut();
        _snack('No tienes acceso a esta clínica o estás desactivado');
        return;
      }

      await AuthStore.login(
        clinicIdValue: clinicId,
        uidValue: user.uid,
        roleValue: info.role,
        emailValue: email,
      );

      // ✅ NO Navigator.pop(); Login es la pantalla raíz.
      if (!mounted) return;
      _snack('Bienvenido ✅');
      return;
    } on FirebaseAuthException catch (e) {
      _snack(_authError(e));
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ese correo ya existe. Usa "Entrar" o cambia correo.';
      case 'invalid-email':
        return 'Correo inválido.';
      case 'weak-password':
        return 'Contraseña muy débil (mínimo 6 caracteres).';
      case 'user-not-found':
        return 'Usuario no encontrado.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-credential':
        return 'Credenciales inválidas.';
      default:
        return 'Auth error: ${e.code}';
    }
  }

  Future<void> _onSubmit() async {
    if (_loading) return;
    if (_createMode) {
      await _crearClinicaYAdmin();
    } else {
      await _entrar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso a la clínica'),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => setState(() => _createMode = !_createMode),
            child: Text(_createMode ? 'Ya tengo clínica' : 'Crear clínica'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _createMode ? 'Crear clínica (Admin)' : 'Entrar a clínica',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _clinicIdCtrl,
            decoration: const InputDecoration(
              labelText: 'Clinic ID (código de clínica)',
              border: OutlineInputBorder(),
              helperText: 'Este código lo compartes al cliente.',
            ),
          ),
          const SizedBox(height: 12),
          if (_createMode) ...[
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
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Correo',
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
            onPressed: _loading ? null : _onSubmit,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(_createMode ? 'Crear clínica y entrar' : 'Entrar'),
          ),
        ],
      ),
    );
  }
}