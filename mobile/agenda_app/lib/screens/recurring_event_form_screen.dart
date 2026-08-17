import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/agenda_provider.dart';

class RecurringEventFormScreen extends StatefulWidget {
  const RecurringEventFormScreen({super.key, this.existing});

  final RecurringEvent? existing;

  @override
  State<RecurringEventFormScreen> createState() => _RecurringEventFormScreenState();
}

class _RecurringEventFormScreenState extends State<RecurringEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _client = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();

  int? _companyId;
  String _category = 'payment';
  String _recurrence = 'monthly';
  int _dayOfMonth = 1;
  int _weekday = 1;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  DateTime _startsOn = DateTime.now();
  final Set<int> _reminders = {1440, 60, 15};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _client.text = e.clientName ?? '';
      _description.text = e.description ?? '';
      if (e.amount != null) _amount.text = e.amount!.toStringAsFixed(0);
      _companyId = e.companyId;
      _category = e.category;
      _recurrence = e.recurrence;
      _dayOfMonth = e.dayOfMonth ?? e.startsOn.day;
      _weekday = e.weekday ?? 1;
      _time = TimeOfDay(hour: e.timeHour, minute: e.timeMinute);
      _startsOn = e.startsOn;
      _reminders
        ..clear()
        ..addAll(e.reminderMinutes);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _client.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _startsOn = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _companyId == null) return;

    final provider = context.read<AgendaProvider>();
    final event = RecurringEvent(
      id: widget.existing?.id ?? 0,
      companyId: _companyId!,
      title: _title.text.trim(),
      clientName: _client.text.trim().isEmpty ? null : _client.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      category: _category,
      amount: double.tryParse(_amount.text.replaceAll(',', '.')),
      recurrence: _recurrence,
      dayOfMonth: _recurrence == 'monthly' || _recurrence == 'yearly' ? _dayOfMonth : null,
      weekday: _recurrence == 'weekly' ? _weekday : null,
      month: _recurrence == 'yearly' ? _startsOn.month : null,
      timeHour: _time.hour,
      timeMinute: _time.minute,
      reminderMinutes: _reminders.toList()..sort(),
      startsOn: _startsOn,
    );

    final error = widget.existing != null
        ? await provider.updateRecurringEvent(event)
        : await provider.saveRecurringEvent(event);

    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.existing != null ? 'Recordatorio actualizado' : 'Recordatorio permanente creado')),
      );
    }
  }

  Future<void> _deactivate() async {
    if (widget.existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar recordatorio'),
        content: const Text('Se cancelarán las próximas ocurrencias programadas. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, desactivar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<AgendaProvider>().deleteRecurringEvent(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgendaProvider>();
    _companyId ??= provider.companies.isNotEmpty ? provider.companies.first.id : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Editar permanente' : 'Nuevo permanente'),
        actions: [
          if (widget.existing != null)
            IconButton(onPressed: _deactivate, icon: const Icon(Icons.delete_outline), tooltip: 'Desactivar'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _catChip('payment', 'Pago', Icons.payments_outlined),
                _catChip('invoice', 'Factura', Icons.receipt_long),
                _catChip('reminder', 'Recordatorio', Icons.notifications_outlined),
                _catChip('general', 'General', Icons.event_repeat),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título *', hintText: 'Pago factura cliente X'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _client,
              decoration: const InputDecoration(labelText: 'Cliente', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Monto (opcional)', prefixIcon: Icon(Icons.attach_money)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _companyId,
              decoration: const InputDecoration(labelText: 'Empresa *'),
              items: provider.companies
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _companyId = v),
            ),
            const SizedBox(height: 20),
            const Text('Repetición', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Día')),
                ButtonSegment(value: 'weekly', label: Text('Sem')),
                ButtonSegment(value: 'monthly', label: Text('Mes')),
                ButtonSegment(value: 'yearly', label: Text('Año')),
              ],
              selected: {_recurrence},
              onSelectionChanged: (s) => setState(() => _recurrence = s.first),
            ),
            const SizedBox(height: 12),
            if (_recurrence == 'monthly' || _recurrence == 'yearly')
              DropdownButtonFormField<int>(
                value: _dayOfMonth,
                decoration: const InputDecoration(labelText: 'Día del mes'),
                items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('Día ${i + 1}'))),
                onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
              ),
            if (_recurrence == 'weekly')
              DropdownButtonFormField<int>(
                value: _weekday,
                decoration: const InputDecoration(labelText: 'Día de la semana'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Lunes')),
                  DropdownMenuItem(value: 2, child: Text('Martes')),
                  DropdownMenuItem(value: 3, child: Text('Miércoles')),
                  DropdownMenuItem(value: 4, child: Text('Jueves')),
                  DropdownMenuItem(value: 5, child: Text('Viernes')),
                  DropdownMenuItem(value: 6, child: Text('Sábado')),
                  DropdownMenuItem(value: 7, child: Text('Domingo')),
                ],
                onChanged: (v) => setState(() => _weekday = v ?? 1),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desde'),
              subtitle: Text('${_startsOn.day}/${_startsOn.month}/${_startsOn.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            const Text('Recordatorios previos', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _reminderChip(1440, '1 día'),
                _reminderChip(720, '12 h'),
                _reminderChip(60, '1 h'),
                _reminderChip(15, '15 min'),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: provider.loading ? null : _save,
              child: Text(provider.loading ? 'Guardando...' : 'Guardar permanente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String value, String label, IconData icon) {
    final selected = _category == value;
    return FilterChip(
      selected: selected,
      label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)]),
      onSelected: (_) => setState(() => _category = value),
    );
  }

  Widget _reminderChip(int minutes, String label) {
    final selected = _reminders.contains(minutes);
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (v) => setState(() {
        if (v) {
          _reminders.add(minutes);
        } else if (_reminders.length > 1) {
          _reminders.remove(minutes);
        }
      }),
    );
  }
}
