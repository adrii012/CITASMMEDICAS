import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'citas_store.dart';
import 'festivos.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Cita> _citasDelDia(DateTime day) {
    final d = _soloFecha(day);
    return CitasStore.citas.where((c) {
      final cd = _soloFecha(c.fechaHora);
      return cd == d;
    }).toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
  }

  @override
  Widget build(BuildContext context) {
    final citasSel =
        _selectedDay == null ? <Cita>[] : _citasDelDia(_selectedDay!);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      _selectedDay != null && isSameDay(_selectedDay, day),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = _soloFecha(selected);
                      _focusedDay = focused;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final count = _citasDelDia(day).length;
                      if (count == 0) return null;

                      return Positioned(
                        bottom: 3,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(width: 1),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      final d = _soloFecha(day);
                      if (!Festivos.esFestivo(d)) return null;

                      return Container(
                        margin: const EdgeInsets.all(6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(width: 2),
                        ),
                        child: Text('${day.day}'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_selectedDay != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Citas del ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (Festivos.estaBloqueado(_selectedDay!))
                    Text('⚠️ ${Festivos.motivoBloqueo(_selectedDay!)}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: citasSel.isEmpty
                ? const Center(child: Text('Selecciona un día para ver sus citas'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: citasSel.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = citasSel[i];
                      final h =
                          '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}';

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(c.paciente),
                          subtitle: Text(
                            'Hora: $h\nEstado: ${c.estado.name}\n${c.notas.isEmpty ? "(sin notas)" : c.notas}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}