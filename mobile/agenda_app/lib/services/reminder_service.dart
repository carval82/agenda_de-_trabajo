import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

    _initialized = true;
  }

  Future<void> scheduleForCommitment(Commitment commitment) async {
    await init();
    await cancelForCommitment(commitment.id);

    for (final minutes in commitment.reminderMinutes) {
      final when = commitment.startsAt.subtract(Duration(minutes: minutes));
      if (when.isBefore(DateTime.now())) continue;

      await _plugin.zonedSchedule(
        _notificationId(commitment.id, minutes),
        'Recordatorio PDA',
        '${commitment.title} en ${_label(minutes)} — ${commitment.company?.name ?? ''}',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'agenda_reminders',
            'Recordatorios de agenda',
            channelDescription: 'Avisos de compromisos LC Design / Interveredanet',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelForCommitment(int commitmentId) async {
    for (final minutes in [5, 15, 30, 60, 120, 1440]) {
      await _plugin.cancel(_notificationId(commitmentId, minutes));
    }
  }

  int _notificationId(int commitmentId, int minutes) => commitmentId * 10000 + minutes;

  String _label(int minutes) {
    if (minutes >= 1440) return '${minutes ~/ 1440} día(s)';
    if (minutes >= 60) return '${minutes ~/ 60} hora(s)';
    return '$minutes min';
  }
}
