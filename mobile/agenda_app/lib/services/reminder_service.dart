import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'agenda_reminders_alarm';
  static const _channelName = 'Alarmas PDA';
  static const _allReminderMinutes = [5, 15, 30, 60, 120, 1440];

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
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Alarmas y recordatorios de compromisos LC Design / Interveredanet',
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

      for (final minutes in commitment.reminderMinutes) {
        final when = commitment.startsAt.subtract(Duration(minutes: minutes));
        if (when.isBefore(DateTime.now())) continue;

        await _plugin.zonedSchedule(
          _notificationId(commitment.id, minutes),
          '⏰ Recordatorio PDA',
          '${commitment.title} en ${_label(minutes)} — ${commitment.company?.name ?? ''}',
          tz.TZDateTime.from(when, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: 'Alarmas de compromisos',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
              ticker: 'Recordatorio PDA',
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e, stack) {
      debugPrint('ReminderService.scheduleForCommitment: $e\n$stack');
    }
  }

  Future<void> cancelForCommitment(int commitmentId) async {
    if (commitmentId <= 0) return;

    try {
      await init();
      for (final minutes in _allReminderMinutes) {
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
      '🔔 Alarma PDA activa',
      'Las notificaciones están configuradas correctamente.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  int _notificationId(int commitmentId, int minutes) => commitmentId * 10000 + minutes;

  String _label(int minutes) {
    if (minutes >= 1440) return '${minutes ~/ 1440} día(s)';
    if (minutes >= 60) return '${minutes ~/ 60} hora(s)';
    return '$minutes min';
  }
}
