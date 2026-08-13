import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'notification_handler.dart';
import 'pda_assistant_service.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'agenda_reminders_alarm';
  static const _channelName = 'Alarmas PDA';
  static const _allReminderMinutes = [5, 15, 30, 60, 120, 1440];
  static const _startSlot = 9999;
  static const _endSlot = 9998;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: NotificationHandler.instance.handle,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Asistente PDA — alarmas y preguntas según horario',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    try {
      await init();
      if (defaultTargetPlatform != TargetPlatform.android) return true;

      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notifications = await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();

      return notifications ?? true;
    } catch (e, stack) {
      debugPrint('ReminderService.requestPermissions: $e\n$stack');
      return false;
    }
  }

  Future<void> scheduleForCommitment(Commitment commitment) async {
    try {
      await init();

      if (commitment.id > 0) {
        await cancelForCommitment(commitment.id);
      }

      if (commitment.status == 'completed' || commitment.status == 'cancelled') {
        return;
      }

      // Recordatorios previos (15m, 1h, etc.)
      for (final minutes in commitment.reminderMinutes) {
        final when = commitment.startsAt.subtract(Duration(minutes: minutes));
        if (when.isBefore(DateTime.now())) continue;

        await _plugin.zonedSchedule(
          _notificationId(commitment.id, minutes),
          '⏰ En ${_label(minutes)}',
          '${commitment.title} — ${commitment.company?.name ?? ''}',
          tz.TZDateTime.from(when, tz.local),
          _details(
            'Pronto comienza tu actividad programada.',
            PdaAssistantService.payloadFor(commitment, 'reminder'),
          ),
          payload: PdaAssistantService.payloadFor(commitment, 'reminder'),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      // A la hora exacta: el asistente PREGUNTA si inicias o aplazas
      if (commitment.startsAt.isAfter(DateTime.now())) {
        await _plugin.zonedSchedule(
          _notificationId(commitment.id, _startSlot),
          '🤖 ¿Inicias ahora?',
          '${commitment.title} — ${commitment.company?.name ?? ''}',
          tz.TZDateTime.from(commitment.startsAt, tz.local),
          _details(
            'Es hora de tu compromiso. ¿Inicias o aplazas?',
            PdaAssistantService.payloadFor(commitment, 'start_prompt'),
            withActions: true,
          ),
          payload: PdaAssistantService.payloadFor(commitment, 'start_prompt'),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      // Al terminar el horario: pregunta si completó
      if (commitment.endsAt.isAfter(DateTime.now())) {
        await _plugin.zonedSchedule(
          _notificationId(commitment.id, _endSlot),
          '✅ ¿Completaste?',
          '${commitment.title}',
          tz.TZDateTime.from(commitment.endsAt, tz.local),
          _details(
            'Terminó el horario. ¿Completaste la actividad?',
            PdaAssistantService.payloadFor(commitment, 'end_prompt'),
            completing: true,
          ),
          payload: PdaAssistantService.payloadFor(commitment, 'end_prompt'),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e, stack) {
      debugPrint('ReminderService.scheduleForCommitment: $e\n$stack');
    }
  }

  NotificationDetails _details(String body, String payload, {bool withActions = false, bool completing = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Asistente PDA',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ticker: 'Asistente PDA',
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
        actions: withActions
            ? [
                const AndroidNotificationAction('start', '▶ Iniciar', showsUserInterface: true),
                const AndroidNotificationAction('postpone', '⏱ Aplazar', showsUserInterface: true),
              ]
            : completing
                ? [
                    const AndroidNotificationAction('complete', '✓ Completé', showsUserInterface: true),
                    const AndroidNotificationAction('postpone', '⏱ Más tiempo', showsUserInterface: true),
                  ]
                : null,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
  }

  Future<void> cancelForCommitment(int commitmentId) async {
    if (commitmentId <= 0) return;

    try {
      await init();
      for (final minutes in [..._allReminderMinutes, _startSlot, _endSlot]) {
        await _plugin.cancel(_notificationId(commitmentId, minutes));
      }
    } catch (e, stack) {
      debugPrint('ReminderService.cancelForCommitment: $e\n$stack');
    }
  }

  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      999999,
      '🤖 Asistente PDA activo',
      'Te avisaré con voz cuando llegue la hora de cada actividad.',
      _details(
        'Prueba exitosa. El asistente está listo.',
        jsonEncode({'id': 0, 'type': 'test'}),
      ),
    );
  }

  int _notificationId(int commitmentId, int slot) => commitmentId * 10000 + slot;

  String _label(int minutes) {
    if (minutes >= 1440) return '${minutes ~/ 1440} día(s)';
    if (minutes >= 60) return '${minutes ~/ 60} hora(s)';
    return '$minutes min';
  }
}
