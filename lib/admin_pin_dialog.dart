// lib/admin_pin_dialog.dart
import 'package:flutter/material.dart';
import 'admin_pin_store.dart';

Future<bool> pedirPin(BuildContext context) async {
  final ctrl = TextEditingController();
  bool ok = false;

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('PIN Admin'),
      content: TextField(
        controller: ctrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'PIN',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            ok = await AdminPinStore.verify(ctrl.text.trim());
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Entrar'),
        ),
      ],
    ),
  );

  ctrl.dispose();
  return ok;
}