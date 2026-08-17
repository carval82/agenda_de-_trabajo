import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Escucha por voz mejorada: dictado, pausa automática, reintentos y confirmación.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  String? _localeId;

  static const _localeCandidates = ['es-CO', 'es-ES', 'es-MX', 'es-US'];

  Future<bool> ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> init() async {
    if (_ready) return true;
    try {
      if (!await ensureMicrophonePermission()) return false;

      _ready = await _stt.initialize(
        onStatus: (s) => debugPrint('STT status: $s'),
        onError: (e) => debugPrint('STT error: $e'),
      );

      if (_ready) {
        _localeId = await _pickBestLocale();
      }
      return _ready;
    } catch (e) {
      debugPrint('VoiceService.init: $e');
      return false;
    }
  }

  Future<String?> _pickBestLocale() async {
    try {
      final locales = await _stt.locales();
      for (final candidate in _localeCandidates) {
        if (locales.any((l) => l.localeId == candidate)) return candidate;
      }
      final es = locales.where((l) => l.localeId.startsWith('es')).toList();
      if (es.isNotEmpty) return es.first.localeId;
    } catch (_) {}
    return 'es_ES';
  }

  bool get isListening => _stt.isListening;

  /// Escucha con dictado, resultados parciales y pausa tras silencio.
  Future<String?> listen({
    Duration listenFor = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 2),
    void Function(String partial)? onPartial,
  }) async {
    if (!await init()) return null;

    final buffer = StringBuffer();
    var lastUpdate = DateTime.now();
    var gotFinal = false;

    await _stt.listen(
      localeId: _localeId,
      listenMode: ListenMode.dictation,
      partialResults: true,
      listenFor: listenFor,
      pauseFor: pauseFor,
      cancelOnError: false,
      onResult: (result) {
        buffer.clear();
        buffer.write(result.recognizedWords.trim());
        lastUpdate = DateTime.now();
        onPartial?.call(buffer.toString());
        if (result.finalResult) gotFinal = true;
      },
    );

    final deadline = DateTime.now().add(listenFor);
    while (DateTime.now().isBefore(deadline)) {
      if (gotFinal && buffer.toString().isNotEmpty) break;
      if (!gotFinal &&
          buffer.isNotEmpty &&
          DateTime.now().difference(lastUpdate) > pauseFor + const Duration(milliseconds: 400)) {
        break;
      }
      if (!_stt.isListening && buffer.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    await stop();
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Escucha con hasta [attempts] intentos si no se captó nada.
  Future<String?> listenWithRetry({
    int attempts = 2,
    void Function(String partial)? onPartial,
  }) async {
    for (var i = 0; i < attempts; i++) {
      final text = await listen(onPartial: onPartial);
      if (text != null && text.trim().isNotEmpty) return text;
      if (i < attempts - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return null;
  }

  /// Pregunta sí/no por voz.
  Future<bool?> confirmYesNo({String? prompt}) async {
    if (prompt != null) {
      // TTS lo maneja el llamador
    }
    final answer = await listen(listenFor: const Duration(seconds: 8));
    if (answer == null) return null;

    final t = answer.toLowerCase();
    if (_matchesAny(t, ['si', 'sí', 'confirmo', 'confirmar', 'dale', 'ok', 'okay', 'claro', 'exacto', 'afirmativo', 'de acuerdo'])) {
      return true;
    }
    if (_matchesAny(t, ['no', 'cancelar', 'cancela', 'negativo', 'mejor no', 'olvidalo', 'olvídalo'])) {
      return false;
    }
    return null;
  }

  bool _matchesAny(String text, List<String> words) {
    return words.any((w) => text.contains(w));
  }

  Future<void> stop() async {
    if (_stt.isListening) {
      try {
        await _stt.stop();
      } catch (_) {}
    }
  }
}
