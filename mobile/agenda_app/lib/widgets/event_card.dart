import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showActions = true,
  });

  final Commitment event;
  final VoidCallback? onTap;
  final bool showActions;

  bool get _isActive => event.status != 'completed' && event.status != 'cancelled';

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(event.company?.color ?? '#2563eb');
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'es');
    final badge = commitmentBadge(event);
    final badgeColor = commitmentBadgeColor(event);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                            _Badge(text: badge, color: badgeColor),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor(event.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel(event.status),
                                style: TextStyle(fontSize: 10, color: statusColor(event.status)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(event.company?.name ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${dateFmt.format(event.startsAt)} → ${DateFormat.Hm().format(event.endsAt)}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        if (event.clientName != null && event.clientName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Cliente: ${event.clientName}', style: const TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(color: priorityColor(event.priority), shape: BoxShape.circle),
                  ),
                ],
              ),
              if (showActions && _isActive) ...[
                const SizedBox(height: 12),
                _ActionRow(event: event),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.event});

  final Commitment event;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AgendaProvider>();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (event.status != 'in_progress')
          _ActionChip(
            icon: Icons.play_arrow_rounded,
            label: 'Iniciar',
            color: AppColors.intervereda,
            onTap: () => _run(context, () => provider.setStatus(event.id, 'in_progress')),
          ),
        if (event.status == 'in_progress')
          _ActionChip(
            icon: Icons.check_circle_outline,
            label: 'Completar',
            color: AppColors.lcdesign,
            onTap: () => _run(context, () => provider.setStatus(event.id, 'completed')),
          ),
        _ActionChip(
          icon: Icons.schedule,
          label: 'Aplazar',
          color: AppColors.amber,
          onTap: () => _postpone(context, event),
        ),
        _ActionChip(
          icon: Icons.close,
          label: 'Cancelar',
          color: Colors.redAccent,
          onTap: () => _confirmCancel(context, event),
        ),
      ],
    );
  }

  Future<void> _run(BuildContext context, Future<String?> Function() action) async {
    final err = await action();
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _confirmCancel(BuildContext context, Commitment event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar compromiso'),
        content: Text('¿Cancelar "${event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, () => context.read<AgendaProvider>().setStatus(event.id, 'cancelled'));
    }
  }

  Future<void> _postpone(BuildContext context, Commitment event) async {
    final duration = event.endsAt.difference(event.startsAt);
    var start = event.startsAt.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(hours: 1))
        : event.startsAt.add(const Duration(hours: 1));
    var end = start.add(duration);

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final fmt = DateFormat('d/M/y HH:mm');
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Aplazar compromiso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nuevo inicio'),
                    subtitle: Text(fmt.format(start)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await _pickDateTime(context, start);
                      if (picked != null) setState(() {
                        start = picked;
                        end = start.add(duration);
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nuevo fin'),
                    subtitle: Text(fmt.format(end)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await _pickDateTime(context, end);
                      if (picked != null) setState(() => end = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('+1 hora'),
                        onPressed: () => setState(() {
                          start = DateTime.now().add(const Duration(hours: 1));
                          end = start.add(duration);
                        }),
                      ),
                      ActionChip(
                        label: const Text('Mañana 9:00'),
                        onPressed: () => setState(() {
                          final t = DateTime.now().add(const Duration(days: 1));
                          start = DateTime(t.year, t.month, t.day, 9);
                          end = start.add(duration);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirmar aplazamiento'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true && context.mounted) {
      await _run(
        context,
        () => context.read<AgendaProvider>().postponeCommitment(event, start, end),
      );
    }
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
