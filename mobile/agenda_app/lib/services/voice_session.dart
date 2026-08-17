import 'package:flutter/foundation.dart';

import '../providers/agenda_provider.dart';
import 'pda_assistant_service.dart';
import 'voice_assistant_controller.dart';

/// Sesión de voz unificada — funciona con la app abierta, minimizada o al tocar la notificación.
class VoiceSessionRunner {
  VoiceSessionRunner._();

  static bool _running = false;

  static Future<void> start({
    AgendaProvider? provider,
    void Function(String partial)? onPartial,
  }) async {
    if (_running) return;
    _running = true;

    try {
      await VoiceAssistantController.runSession(provider: provider, onPartial: onPartial);
    } catch (e) {
      debugPrint('VoiceSessionRunner: $e');
      await PdaAssistantService.instance.speak('Hubo un problema con el micrófono.');
    } finally {
      _running = false;
    }
  }

  static Future<void> speakStatus({
    AgendaProvider? provider,
    void Function(String partial)? onPartial,
  }) async {
    await VoiceAssistantController.process('estado', provider: provider, onPartial: onPartial);
  }
}
