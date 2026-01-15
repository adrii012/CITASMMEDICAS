import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'citas_store.dart';

class ExportPdf {
  static Future<void> generarYCompartir(
      BuildContext context, List<Cita> citas) async {
    final doc = pw.Document();

    final rows = citas.map((c) {
      final fecha =
          '${c.fechaHora.day}/${c.fechaHora.month}/${c.fechaHora.year}';
      final hora =
          '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';
      final estado = c.estado.name;

      return [c.paciente, fecha, hora, estado, c.notas];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text('Reporte de Citas', style: pw.TextStyle(fontSize: 20)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Paciente', 'Fecha', 'Hora', 'Estado', 'Notas'],
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    // Muestra diálogo para imprimir/guardar/compartir
    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (format) async => Uint8List.fromList(bytes),
      name: 'citas_medicas.pdf',
    );
  }
}