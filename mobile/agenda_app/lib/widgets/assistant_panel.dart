import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/pda_assistant_service.dart';
import '../theme/app_theme.dart';

class AssistantPanel extends StatelessWidget {
  const AssistantPanel({
    super.key,
    required this.todayEvents,
    required this.onSpeakDay,
  });

  final List<Commitment> todayEvents;
  final VoidCallback onSpeakDay;

  @override
  Widget build(BuildContext context) {
    final assistant = PdaAssistantService.instance;
    final current = assistant.currentActivity();
    final next = assistant.nextActivity();
    final fmt = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.lcdesign.withOpacity(0.25),
                AppColors.intervereda.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.lcdesign.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lcdesign.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: AppColors.lcdesign, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Asistente PDA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('Te aviso y pregunto según tu horario', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Escuchar agenda de hoy',
                    onPressed: onSpeakDay,
                    icon: const Icon(Icons.volume_up_rounded, color: AppColors.intervereda),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (current != null)
                _NowCard(
                  label: current.status == 'in_progress' ? 'EN CURSO' : '¡ES AHORA!',
                  title: current.title,
                  subtitle: '${current.company?.name} · ${fmt.format(current.startsAt)}-${fmt.format(current.endsAt)}',
                  color: current.status == 'in_progress' ? AppColors.intervereda : AppColors.amber,
                  pulsing: current.status != 'in_progress',
                )
              else if (next != null)
                _NowCard(
                  label: 'PRÓXIMO',
                  title: next.title,
                  subtitle: '${next.company?.name} · ${fmt.format(next.startsAt)} · ${timeUntil(next.startsAt)}',
                  color: AppColors.lcdesign,
                  pulsing: false,
                )
              else
                const _NowCard(
                  label: 'LIBRE',
                  title: 'Sin actividades pendientes',
                  subtitle: 'Disfruta tu tiempo o agenda algo nuevo',
                  color: AppColors.muted,
                  pulsing: false,
                ),
            ],
          ),
        ),
        if (todayEvents.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('TU DÍA', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.muted)),
          const SizedBox(height: 10),
          ...todayEvents.map((e) => _TimelineTile(event: e)),
        ],
      ],
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.pulsing,
  });

  final String label;
  final String title;
  final String subtitle;
  final Color color;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pulsing)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final Commitment event;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(event.company?.color ?? '#2563eb');
    final fmt = DateFormat('HH:mm');
    final done = event.status == 'completed';
    final active = event.status == 'in_progress';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(fmt.format(event.startsAt), style: const TextStyle(fontSize: 12, color: AppColors.muted, fontFeatures: [])),
          const SizedBox(width: 10),
          Container(width: 3, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? AppColors.muted : AppColors.text,
                  ),
                ),
                Text(
                  '${statusLabel(event.status)} · ${event.company?.name ?? ''}',
                  style: TextStyle(fontSize: 11, color: active ? AppColors.intervereda : AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
