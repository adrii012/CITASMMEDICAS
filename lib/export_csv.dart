import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'citas_store.dart';
import 'pacientes_store.dart';

class ExportCsv {
  static Future<void> exportar(BuildContext context, List<Cita> citas) async {
    // ✅ Agregamos columnas odontología sin quitar las viejas
    final header = [
      'paciente',
      'fecha',
      'hora',
      'estado',
      'servicio',
      'motivo',
      'pieza',
      'telefono',
      'notas',
    ];

    final lines = <List<String>>[header];

    for (final c in citas) {
      final p = PacientesStore.porId(c.pacienteId ?? '');
      final nombre = p?.nombre ?? c.paciente;

      final fecha = '${c.fechaHora.day}/${c.fechaHora.month}/${c.fechaHora.year}';
      final hora =
          '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';

      // Tel: local o de la cita
      final tel = (p?.telefono ?? c.phone).trim();

      lines.add([
        nombre,
        fecha,
        hora,
        c.estado.name,
        c.service,
        c.motivo,
        c.pieza,
        tel,
        c.notas,
      ]);
    }

    final csv = const ListToCsvConverter().convert(lines);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/citas_medicas.csv');
    await file.writeAsString(csv, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exportación de citas (CSV)',
    );
  }
}

/// Convertidor simple CSV (sin paquete extra)
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<String>> rows) {
    String esc(String v) {
      final needs = v.contains(',') || v.contains('\n') || v.contains('"');
      final fixed = v.replaceAll('"', '""');
      return needs ? '"$fixed"' : fixed;
    }

    return rows.map((r) => r.map(esc).join(',')).join('\n');
  }
}