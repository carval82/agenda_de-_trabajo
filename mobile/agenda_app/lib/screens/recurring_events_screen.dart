import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';
import 'recurring_event_form_screen.dart';

class RecurringEventsScreen extends StatelessWidget {
  const RecurringEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgendaProvider>();
    final events = provider.recurringEvents.where((e) => e.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios permanentes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: provider.loading ? null : provider.loadRecurringEvents,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecurringEventFormScreen()),
        ),
        icon: const Icon(Icons.repeat),
        label: const Text('Nuevo permanente'),
      ),
      body: provider.loading && events.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined, size: 64, color: AppColors.muted.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'Sin recordatorios permanentes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea pagos de facturas, cobros mensuales u otras alertas que se repiten solas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    Company? company;
                    for (final c in provider.companies) {
                      if (c.id == event.companyId) {
                        company = c;
                        break;
                      }
                    }
                    final color = parseHexColor(company?.color ?? '#2563eb');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecurringEventFormScreen(existing: event),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      event.categoryLabel,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.intervereda.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.repeat, size: 12, color: AppColors.intervereda),
                                        const SizedBox(width: 4),
                                        Text(
                                          event.recurrenceLabel,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.intervereda),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(event.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              if (event.clientName != null && event.clientName!.isNotEmpty)
                                Text('Cliente: ${event.clientName}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              if (event.amount != null)
                                Text(
                                  '\$${event.amount!.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.amber),
                                ),
                              const SizedBox(height: 6),
                              Text(event.scheduleSummary, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                              Text(company?.name ?? '', style: TextStyle(fontSize: 12, color: color)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
