import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart' show navigatorKey;
import '../models/models.dart';
import '../providers/agenda_provider.dart';
import '../services/pda_assistant_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/assistant_panel.dart';
import '../widgets/event_card.dart';
import '../widgets/ui_widgets.dart';
import 'commitment_form_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _briefingDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupAssistant());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PdaAssistantService.instance.stopWatching();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PdaAssistantService.instance.startWatching();
    } else if (state == AppLifecycleState.paused) {
      PdaAssistantService.instance.stopWatching();
    }
  }

  Future<void> _setupAssistant() async {
    await ReminderService.instance.requestPermissions();
    final provider = context.read<AgendaProvider>();

    PdaAssistantService.instance.attach(
      navigatorKey: navigatorKey,
      onAction: (id, action) => provider.handleAssistantAction(id, action),
    );

    if (!_briefingDone && mounted) {
      _briefingDone = true;
      final today = provider.todayAgenda();
      await PdaAssistantService.instance.dailyBriefing(today);
    }

    PdaAssistantService.instance.startWatching();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgendaProvider>();
    final dayEvents = provider.eventsForDay(_selectedDay);
    final todayAgenda = provider.todayAgenda();

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
                  const Text('Asistente PDA', style: TextStyle(fontSize: 16)),
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
            tooltip: 'Escuchar mi día',
            onPressed: () => PdaAssistantService.instance.dailyBriefing(todayAgenda),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: provider.loading ? null : provider.loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              PdaAssistantService.instance.stopWatching();
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
                  AssistantPanel(
                    todayEvents: todayAgenda,
                    onSpeakDay: () => PdaAssistantService.instance.dailyBriefing(todayAgenda),
                  ),
                  const SizedBox(height: 20),
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
                        calendarStyle: const CalendarStyle(
                          todayDecoration: BoxDecoration(color: AppColors.lcdesign, shape: BoxShape.circle),
                          selectedDecoration: BoxDecoration(color: AppColors.intervereda, shape: BoxShape.circle),
                          markerDecoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
                          weekendTextStyle: TextStyle(color: Color(0xFFFCA5A5)),
                        ),
                        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(title: 'Detalle del día', badge: DateFormat('d MMM', 'es').format(_selectedDay)),
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
                          showActions: false,
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
