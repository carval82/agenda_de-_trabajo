import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationActionCallback = Future<void> Function(int commitmentId, String action);
typedef MorningBriefingCallback = Future<void> Function();
typedef VoiceAssistantCallback = Future<void> Function(String action);

class NotificationHandler {
  NotificationHandler._();
  static final NotificationHandler instance = NotificationHandler._();

  NotificationActionCallback? onAction;
  MorningBriefingCallback? onMorningBriefing;
  VoiceAssistantCallback? onVoiceAssistant;

  /// Pendiente al abrir la app desde notificación de voz.
  bool pendingVoiceSession = false;
  String pendingVoiceAction = 'voice';

  void handle(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      if (type == 'morning_briefing') {
        onMorningBriefing?.call();
        return;
      }

      if (type == 'voice_assistant') {
        final action = response.actionId ?? 'voice';
        pendingVoiceSession = true;
        pendingVoiceAction = action;
        onVoiceAssistant?.call(action);
        return;
      }

      final id = data['id'] as int?;
      if (id == null) return;

      final action = response.actionId ?? 'open';
      onAction?.call(id, action);
    } catch (_) {}
  }

  void clearPendingVoice() {
    pendingVoiceSession = false;
    pendingVoiceAction = 'voice';
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationHandler.instance.handle(response);
}
