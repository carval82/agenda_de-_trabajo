import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationActionCallback = Future<void> Function(int commitmentId, String action);

class NotificationHandler {
  NotificationHandler._();
  static final NotificationHandler instance = NotificationHandler._();

  NotificationActionCallback? onAction;

  void handle(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final id = data['id'] as int?;
      if (id == null) return;

      final action = response.actionId ?? 'open';
      onAction?.call(id, action);
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationHandler.instance.handle(response);
}
