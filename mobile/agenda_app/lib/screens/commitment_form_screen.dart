import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';

class CommitmentFormScreen extends StatefulWidget {
  const CommitmentFormScreen({super.key, this.existing, this.selectedDay});

  final Commitment? existing;
  final DateTime? selectedDay;

  @override
  State<CommitmentFormScreen> createState() => _CommitmentFormScreenState();
}

class _CommitmentFormScreenState extends State<CommitmentFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _client = TextEditingController();

  int? _companyId;
  String _priority = 'medium';
  DateTime? _start;
  DateTime? _end;
  final Set<int> _reminders = {15, 60};
  String? _conflict;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _description.text = existing.description ?? '';
      _location.text = existing.location ?? '';
      _client.text = existing.clientName ?? '';
      _companyId = existing.companyId;
      _priority = existing.priority;
      _start = existing.startsAt;
      _end = existing.endsAt;
      _reminders
        ..clear()
        ..addAll(existing.reminderMinutes);
    } else {
      final day = widget.selectedDay ?? DateTime.now();
      _start = DateTime(day.year, day.month, day.day, 9);
      _end = _start!.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start! : _end!;
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;

    setState(() {
      final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _start = value;
        if (_end == null || !_end!.isAfter(_start!)) _end = _start!.add(const Duration(hours: 1));
      } else {
        _end = value;
      }
    });
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.muted)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgendaProvider>();
    _companyId ??= provider.companies.firstOrNull?.id;
    final fmt = DateFormat('d/M/y HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nuevo compromiso' : 'Editar compromiso'),
        actions: [
          if (widget.existing != null)
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar'),
                    content: const Text('¿Eliminar este compromiso?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                    ],
                  ),
                );
                if (ok == true) {
                  await provider.deleteCommitment(widget.existing!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Información', [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título del trabajo')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _companyId,
              decoration: const InputDecoration(labelText: 'Empresa'),
              items: provider.companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _companyId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Prioridad'),
              items: ['low', 'medium', 'high', 'urgent']
                  .map((p) => DropdownMenuItem(value: p, child: Text(priorityLabel(p))))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
            ),
          ]),
          _section('Horario', [
            _timeTile('Inicio', _start, fmt, () => _pickDateTime(isStart: true)),
            const Divider(color: AppColors.border),
            _timeTile('Fin', _end, fmt, () => _pickDateTime(isStart: false)),
          ]),
          _section('Detalles', [
            TextField(controller: _client, decoration: const InputDecoration(labelText: 'Cliente / Proyecto')),
            const SizedBox(height: 12),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'Ubicación')),
            const SizedBox(height: 12),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 3),
          ]),
          _section('Recordatorios PDA', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 15, 30, 60, 120, 1440].map((minutes) {
                final selected = _reminders.contains(minutes);
                return FilterChip(
                  label: Text(minutes >= 60 ? '${minutes ~/ 60}h' : '${minutes}m'),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _reminders.remove(minutes);
                    } else {
                      _reminders.add(minutes);
                    }
                  }),
                );
              }).toList(),
            ),
          ]),
          if (_conflict != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.amber.withOpacity(0.35)),
              ),
              child: Text(_conflict!, style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 13)),
            ),
          FilledButton(
            onPressed: provider.loading || _companyId == null || _start == null || _end == null
                ? null
                : () async {
                    final commitment = Commitment(
                      id: widget.existing?.id ?? 0,
                      companyId: _companyId!,
                      title: _title.text.trim(),
                      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
                      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
                      clientName: _client.text.trim().isEmpty ? null : _client.text.trim(),
                      startsAt: _start!,
                      endsAt: _end!,
                      priority: _priority,
                      reminderMinutes: _reminders.toList()..sort(),
                    );

                    final conflict = await provider.saveCommitment(commitment, editingId: widget.existing?.id);
                    if (!context.mounted) return;
                    if (conflict != null) {
                      setState(() => _conflict = conflict);
                    } else {
                      Navigator.pop(context);
                    }
                  },
            child: Text(provider.loading ? 'Guardando...' : 'Guardar compromiso'),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(String label, DateTime? value, DateFormat fmt, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.panelLight, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.schedule, size: 20),
      ),
      title: Text(label),
      subtitle: Text(value == null ? 'Seleccionar' : fmt.format(value)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
