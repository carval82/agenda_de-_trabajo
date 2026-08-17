import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart' show navigatorKey;
import '../providers/agenda_provider.dart';
import '../services/notification_handler.dart';
import '../services/pda_assistant_service.dart';
import '../services/reminder_service.dart';
import '../services/voice_session.dart';
import '../theme/app_theme.dart';
import '../widgets/assistant_panel.dart';
import '../widgets/event_card.dart';
import '../widgets/ui_widgets.dart';
import 'commitment_form_screen.dart';
import 'login_screen.dart';
import 'recurring_events_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _listening = false;
  String? _voiceHint;

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
      context.read<AgendaProvider>().runMorningCheckIfNeeded();
    } else if (state == AppLifecycleState.paused) {
      PdaAssistantService.instance.stopWatching();
    }
  }

  Future<void> _setupAssistant() async {
    await ReminderService.instance.requestPermissions();
    if (!mounted) return;
    final provider = context.read<AgendaProvider>();

    PdaAssistantService.instance.attach(
      navigatorKey: navigatorKey,
      onAction: (id, action) => provider.handleAssistantAction(id, action),
    );
    PdaAssistantService.instance.onDayModeChanged = () {
      if (mounted) setState(() {});
    };

    PdaAssistantService.instance.startWatching();

    if (NotificationHandler.instance.pendingVoiceSession) {
      final action = NotificationHandler.instance.pendingVoiceAction;
      NotificationHandler.instance.clearPendingVoice();
      if (action == 'status') {
        await VoiceSessionRunner.speakStatus(provider: provider);
      } else {
        await VoiceSessionRunner.start(provider: provider);
      }
    }
  }

  Future<void> _handleVoice() async {
    if (_listening) return;

    setState(() {
      _listening = true;
      _voiceHint = 'Di: qué tengo hoy, estado, próximo…';
    });

    final provider = context.read<AgendaProvider>();
    await VoiceSessionRunner.start(
      provider: provider,
      onPartial: (partial) {
        if (mounted) setState(() => _voiceHint = 'Escuchando: "$partial"');
      },
    );

    if (mounted) {
      await provider.refreshAssistantState();
      setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgendaProvider>();
    final dayEvents = provider.eventsForDay(_selectedDay);
    final todayAgenda = provider.todayAgenda();
    final dayMode = provider.dayMode;

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
                  Text(
                    provider.user?.name.split(' ').first ?? 'Asistente PDA',
                    style: const TextStyle(fontSize: 16),
                  ),
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
            tooltip: 'Briefing del día',
            onPressed: () => provider.runMorningRoutine(),
            icon: const Icon(Icons.wb_sunny_outlined),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'voice',
            mini: true,
            backgroundColor: _listening ? AppColors.amber : AppColors.lcdesign,
            onPressed: _handleVoice,
            child: Icon(_listening ? Icons.mic : Icons.mic_none_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CommitmentFormScreen(selectedDay: _selectedDay)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Agendar'),
          ),
        ],
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
                    dayMode: dayMode,
                    userName: provider.user?.name,
                    listening: _listening,
                    backgroundEnabled: provider.backgroundAssistantEnabled,
                    onBackgroundChanged: (v) => provider.setBackgroundAssistant(v),
                    onSpeakDay: () => provider.runMorningRoutine(),
                    onVoiceTap: _handleVoice,
                  ),
                  if (_voiceHint != null) ...[
                    const SizedBox(height: 8),
                    Text(_voiceHint!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                  const SizedBox(height: 20),
                  _PermanentEventsBanner(
                    count: provider.recurringEvents.where((e) => e.isActive).length,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecurringEventsScreen()),
                    ),
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
                        icon: Icons.business_outlined,
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
                        child: Center(
                          child: Text('Sin compromisos este día', style: TextStyle(color: AppColors.muted)),
                        ),
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
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }
}

class _PermanentEventsBanner extends StatelessWidget {
  const _PermanentEventsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.repeat, color: AppColors.amber),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recordatorios permanentes', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      count > 0
                          ? '$count activo(s) · pagos, facturas y alertas recurrentes'
                          : 'Pagos de facturas, cobros mensuales y más',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
