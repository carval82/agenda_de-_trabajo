import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/models.dart';
import '../providers/agenda_provider.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/ui_widgets.dart';
import 'commitment_form_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReminderService.instance.requestPermissions();
    });
  }

  int _countToday(List<Commitment> events) {
    final now = DateTime.now();
    return events.where((e) =>
        e.startsAt.year == now.year && e.startsAt.month == now.month && e.startsAt.day == now.day).length;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgendaProvider>();
    final dayEvents = provider.eventsForDay(_selectedDay);
    final visibleUpcoming = provider.upcoming.where((e) => provider.visibleCompanies.contains(e.companyId)).take(8);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(variant: AppLogoVariant.compact, height: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agenda PDA', style: TextStyle(fontSize: 16)),
                  Text(
                    DateFormat('EEEE d MMMM', 'es').format(DateTime.now()),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 16,
        actions: [
          IconButton(
            tooltip: 'Probar alarma',
            onPressed: () => ReminderService.instance.showTestNotification(),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: provider.loading ? null : provider.loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await provider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CommitmentFormScreen(selectedDay: _selectedDay)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Agendar'),
      ),
      body: provider.loading && provider.companies.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(child: StatCard(label: 'Hoy', value: '${_countToday(provider.calendarEvents)}', color: AppColors.lcdesign)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(label: 'Próximos', value: '${provider.upcoming.length}', color: AppColors.intervereda)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: provider.companies.map((company) {
                      final active = provider.visibleCompanies.contains(company.id);
                      return CompanyFilterChip(
                        label: company.name,
                        color: parseHexColor(company.color),
                        selected: active,
                        icon: company.slug == 'lcdesign' ? Icons.code : Icons.wifi,
                        onTap: () => provider.toggleCompany(company.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020),
                        lastDay: DateTime.utc(2035),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                        calendarFormat: CalendarFormat.twoWeeks,
                        locale: 'es_ES',
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        onDaySelected: (selected, focused) => setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        }),
                        eventLoader: provider.eventsForDay,
                        calendarStyle: CalendarStyle(
                          todayDecoration: const BoxDecoration(color: AppColors.lcdesign, shape: BoxShape.circle),
                          selectedDecoration: const BoxDecoration(color: AppColors.intervereda, shape: BoxShape.circle),
                          markerDecoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
                          weekendTextStyle: const TextStyle(color: Color(0xFFFCA5A5)),
                        ),
                        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(title: 'Día seleccionado', badge: DateFormat('d MMM', 'es').format(_selectedDay)),
                  const SizedBox(height: 10),
                  if (dayEvents.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Sin compromisos este día', style: TextStyle(color: AppColors.muted))),
                      ),
                    )
                  else
                    ...dayEvents.map((event) => EventCard(
                          event: event,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CommitmentFormScreen(existing: event)),
                          ),
                        )),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Próximos compromisos', badge: 'PDA'),
                  const SizedBox(height: 10),
                  ...visibleUpcoming.map((event) => EventCard(
                        event: event,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CommitmentFormScreen(existing: event)),
                        ),
                      )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
