import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onTap});

  final Commitment event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(event.company?.color ?? '#2563eb');
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'es');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                        Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.amber.withOpacity(0.25)),
                          ),
                          child: Text(timeUntil(event.startsAt), style: const TextStyle(fontSize: 10, color: Color(0xFFFCD34D))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(event.company?.name ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
        ),
      ),
    );
  }
}
