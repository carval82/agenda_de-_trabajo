import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Modal que el asistente PDA muestra al llegar la hora de un compromiso.
class ActivityPromptSheet extends StatelessWidget {
  const ActivityPromptSheet({
    super.key,
    required this.event,
    required this.onStart,
    required this.onPostpone,
    required this.onComplete,
    this.completing = false,
  });

  final Commitment event;
  final VoidCallback onStart;
  final VoidCallback onPostpone;
  final VoidCallback onComplete;
  final bool completing;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(event.company?.color ?? '#2563eb');
    final fmt = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
              ),
              child: Icon(completing ? Icons.check_circle_outline : Icons.record_voice_over, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              completing ? '¿Completaste la actividad?' : 'Es hora de tu compromiso',
              style: const TextStyle(fontSize: 13, color: AppColors.muted, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${event.company?.name ?? ''} · ${fmt.format(event.startsAt)} - ${fmt.format(event.endsAt)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📍 ${event.location}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
            const SizedBox(height: 24),
            if (!completing) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Sí, iniciar actividad'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.intervereda,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPostpone,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Aplazar 1 hora'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: BorderSide(color: AppColors.amber.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check),
                  label: const Text('Sí, completada'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lcdesign,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPostpone,
                  icon: const Icon(Icons.more_time),
                  label: const Text('Necesito más tiempo'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
