import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'assistant_remote.dart';
import 'pda_assistant_service.dart';
import 'reminder_service.dart';

/// Servicio en primer plano que mantiene el asistente activo con la app cerrada o en segundo plano.
class BackgroundAssistantService {
  BackgroundAssistantService._();
  static final BackgroundAssistantService instance = BackgroundAssistantService._();

  static const _prefEnabled = 'background_assistant_enabled';

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceNotificationId: 7777,
        initialNotificationTitle: 'Asistente PDA',
        initialNotificationContent: 'Activo en segundo plano — usa la notificación para hablar',
        foregroundServiceTypes: const [
          AndroidForegroundType.dataSync,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    service.on('morningBriefing').listen((_) async {
      await BackgroundAssistantService.runMorningBriefingStandalone();
    });

    service.on('refreshCache').listen((_) async {
      await _refreshCache();
    });
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, enabled);

    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }

  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  Future<void> start() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    await ReminderService.instance.showAssistantBackgroundNotification();
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    await ReminderService.instance.hideAssistantBackgroundNotification();
  }

  Future<void> ensureStartedIfEnabled() async {
    if (await isEnabled()) {
      await start();
    }
  }

  static Future<void> _refreshCache() async {
    final all = await AssistantRemote.fetchActiveCommitments();
    PdaAssistantService.instance.updateCommitments(all);
    final today = await AssistantRemote.fetchTodayCommitments();
    await PdaAssistantService.instance.evaluateDayModeFromEvents(today);
  }

  static Future<void> runMorningBriefingStandalone() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    if (await PdaAssistantService.instance.morningBriefingDoneToday()) return;

    final all = await AssistantRemote.fetchActiveCommitments();
    PdaAssistantService.instance.updateCommitments(all);
    final today = await AssistantRemote.fetchTodayCommitments();
    final name = prefs.getString('user_name');

    await PdaAssistantService.instance.runMorningRoutine(today, name: name);

    final mode = PdaAssistantService.instance.dayMode;
    final summary = mode == DayMode.rest
        ? 'Modo reposo — no hay eventos hoy.'
        : 'Día activo — ${today.length} actividad(es) programada(s).';

    await ReminderService.instance.showMorningSummaryNotification(summary);
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
  }

  service.on('stop').listen((_) {
    service.stopSelf();
  });

  // Revisión periódica: briefing 7:00, modo reposo, mantener notificación
  Timer.periodic(const Duration(seconds: 50), (timer) async {
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: 'Asistente PDA en segundo plano',
        content: 'Toca 🎤 Hablar en la notificación para preguntar',
      );
    }

    await BackgroundAssistantService._refreshCache();

    final now = DateTime.now();
    if (now.hour == PdaAssistantService.morningHour && now.minute <= 10) {
      if (!await PdaAssistantService.instance.morningBriefingDoneToday()) {
        await BackgroundAssistantService.runMorningBriefingStandalone();
        service.invoke('morningBriefing');
      }
    }
  });
}
