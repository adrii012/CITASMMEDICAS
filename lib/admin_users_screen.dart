// lib/admin_users_screen.dart
import 'package:flutter/material.dart';

import 'auth_store.dart';
import 'local_user_store.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  String _err = '';
  List<LocalUser> _users = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _err = '';
    });

    try {
      final clinicId = AuthStore.requireClinicId();
      final list = await LocalUserStore.listUsers(clinicId);
      if (!mounted) return;
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createStaffDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crear usuario STAFF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo (staff)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(
                labelText: 'Contraseña temporal',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: pásale esta contraseña al cliente.\nLuego tú se la puedes resetear cuando quieras.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                final clinicId = AuthStore.requireClinicId();
                await LocalUserStore.createStaffUser(
                  clinicId: clinicId,
                  email: emailCtrl.text.trim(),
                  tempPassword: passCtrl.text,
                  active: true,
                );
                if (context.mounted) Navigator.pop(context);
                _snack('Staff creado ✅');
                await _refresh();
              } catch (e) {
                _snack('Error: $e');
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassDialog(String email) async {
    final passCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetear contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(email, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                final clinicId = AuthStore.requireClinicId();
                await LocalUserStore.resetPasswordByEmail(
                  clinicId: clinicId,
                  email: email,
                  newPassword: passCtrl.text,
                );
                if (context.mounted) Navigator.pop(context);
                _snack('Contraseña actualizada ✅');
              } catch (e) {
                _snack('Error: $e');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(String title, String msg, Future<void> Function() action) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await action();
                _snack('Listo ✅');
                await _refresh();
              } catch (e) {
                _snack('Error: $e');
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthStore.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acceso denegado')),
      );
    }

    final clinicId = AuthStore.clinicId.value ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: Text('Usuarios ($clinicId)'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createStaffDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Crear staff'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err.isNotEmpty
              ? Center(child: Text(_err))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final isAdmin = u.role == 'admin';
                    final active = u.active;

                    return Card(
                      child: ListTile(
                        leading: Icon(isAdmin ? Icons.shield : Icons.badge),
                        title: Text(u.email),
                        subtitle: Text('Rol: ${u.role} • Estado: ${active ? "ACTIVO" : "DESACTIVADO"}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            final clinicId = AuthStore.requireClinicId();

                            if (v == 'reset') {
                              await _resetPassDialog(u.email);
                              return;
                            }

                            if (v == 'toggle') {
                              await _confirm(
                                active ? 'Desactivar usuario' : 'Activar usuario',
                                'Usuario: ${u.email}',
                                () => LocalUserStore.setActiveByEmail(
                                  clinicId: clinicId,
                                  email: u.email,
                                  active: !active,
                                ),
                              );
                              return;
                            }

                            if (v == 'role_admin') {
                              await _confirm(
                                'Hacer ADMIN',
                                'Usuario: ${u.email}',
                                () => LocalUserStore.setRoleByEmail(
                                  clinicId: clinicId,
                                  email: u.email,
                                  role: 'admin',
                                ),
                              );
                              return;
                            }

                            if (v == 'role_staff') {
                              await _confirm(
                                'Hacer STAFF',
                                'Usuario: ${u.email}',
                                () => LocalUserStore.setRoleByEmail(
                                  clinicId: clinicId,
                                  email: u.email,
                                  role: 'staff',
                                ),
                              );
                              return;
                            }

                            if (v == 'delete') {
                              await _confirm(
                                'Eliminar usuario',
                                'Se eliminará: ${u.email}\n(Esto no se puede deshacer)',
                                () => LocalUserStore.deleteUserByEmail(
                                  clinicId: clinicId,
                                  email: u.email,
                                ),
                              );
                              return;
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'reset',
                              child: Text('Reset contraseña'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(active ? 'Desactivar' : 'Activar'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'role_admin',
                              child: Text('Cambiar a admin'),
                            ),
                            const PopupMenuItem(
                              value: 'role_staff',
                              child: Text('Cambiar a staff'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}