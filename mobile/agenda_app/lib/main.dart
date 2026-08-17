import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'providers/agenda_provider.dart';
import 'screens/connection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/background_assistant_service.dart';
import 'services/connection_service.dart';
import 'services/notification_handler.dart';
import 'services/pda_assistant_service.dart';
import 'services/reminder_service.dart';
import 'services/voice_session.dart';
import 'theme/app_theme.dart';
import 'widgets/ui_widgets.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  await ApiConfig.init();
  await ReminderService.instance.init();
  await BackgroundAssistantService.instance.initialize();

  NotificationHandler.instance.onAction = (id, action) async {
    await PdaAssistantService.instance.handleNotificationAction(id, action);
  };

  NotificationHandler.instance.onMorningBriefing = () async {
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await ctx.read<AgendaProvider>().runMorningRoutine();
      return;
    }
    await BackgroundAssistantService.runMorningBriefingStandalone();
  };

  NotificationHandler.instance.onVoiceAssistant = (action) async {
    final ctx = navigatorKey.currentContext;
    AgendaProvider? provider;
    if (ctx != null && ctx.mounted) {
      provider = ctx.read<AgendaProvider>();
    }

    if (action == 'status') {
      await VoiceSessionRunner.speakStatus(provider: provider);
    } else {
      await VoiceSessionRunner.start(provider: provider);
    }
    NotificationHandler.instance.clearPendingVoice();
  };

  final api = ApiService();
  runApp(AgendaApp(api: api));
}

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key, required this.api});

  final ApiService api;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AgendaProvider(api),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Agenda PDA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const SplashGate(),
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool? _serverOk;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final connection = ConnectionService();
    final serverOk = await connection.checkServer();
    if (!mounted) return;

    if (!serverOk) {
      setState(() => _serverOk = false);
      return;
    }

    setState(() => _serverOk = true);
    final provider = context.read<AgendaProvider>();
    final ok = await provider.restoreSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ok ? const HomeScreen() : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_serverOk == false) {
      return ConnectionScreen(onConnected: () {
        setState(() => _serverOk = null);
        _boot();
      });
    }

    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PdaLogo(size: 180, variant: AppLogoVariant.hero),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
