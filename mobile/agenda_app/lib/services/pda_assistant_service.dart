import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../widgets/activity_prompt_sheet.dart';

class PdaAssistantService {
  PdaAssistantService._();
  static final PdaAssistantService instance = PdaAssistantService._();

  final FlutterTts _tts = FlutterTts();
  Timer? _watchTimer;
  GlobalKey<NavigatorState>? _navigatorKey;
  Future<void> Function(int id, String action)? _onAction;
  List<Commitment> _commitments = [];
  final Set<String> _promptedKeys = {};
  bool _ttsReady = false;

  Future<void> init() async {
    if (_ttsReady) return;
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ttsReady = true;
  }

  void attach({
    required GlobalKey<NavigatorState> navigatorKey,
    required Future<void> Function(int id, String action) onAction,
  }) {
    _navigatorKey = navigatorKey;
    _onAction = onAction;
  }

  void updateCommitments(List<Commitment> items) {
    _commitments = items.where((c) => c.status != 'completed' && c.status != 'cancelled').toList();
  }

  void startWatching() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkSchedule());
    _checkSchedule();
  }

  void stopWatching() {
    _watchTimer?.cancel();
  }

  Future<void> speak(String text) async {
    try {
      await init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('PdaAssistant TTS: $e');
    }
  }

  Future<void> dailyBriefing(List<Commitment> todayEvents) async {
    if (todayEvents.isEmpty) {
      await speak('Buenos días. No tienes compromisos agendados para hoy.');
      return;
    }

    todayEvents.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final count = todayEvents.length;
    final next = todayEvents.firstWhere(
      (e) => e.endsAt.isAfter(DateTime.now()),
      orElse: () => todayEvents.first,
    );
    final time = DateFormat('HH:mm').format(next.startsAt);
    final company = next.company?.name ?? '';

    await speak(
      'Buenos días. Hoy tienes $count ${count == 1 ? 'compromiso' : 'compromisos'}. '
      'Tu próxima actividad es ${next.title}, a las $time, con $company.',
    );
  }

  Future<void> handleNotificationAction(int id, String action) async {
    final mapped = _mapAction(action);
    switch (action) {
      case 'start':
        await speak('Perfecto. Actividad iniciada.');
        break;
      case 'postpone':
        await speak('De acuerdo. Aplazamos una hora.');
        break;
      case 'complete':
        await speak('Actividad completada. Buen trabajo.');
        break;
      default:
        final event = _find(id);
        if (event != null) await _showPrompt(event, fromNotification: true);
        return;
    }
    await _onAction?.call(id, mapped);
  }

  String _mapAction(String action) {
    switch (action) {
      case 'start':
        return 'in_progress';
      case 'postpone':
        return 'postpone_1h';
      case 'complete':
        return 'completed';
      default:
        return action;
    }
  }

  Commitment? currentActivity() {
    final now = DateTime.now();
    for (final e in _commitments) {
      if (e.status == 'in_progress') return e;
      if (now.isAfter(e.startsAt) && now.isBefore(e.endsAt) && e.status == 'scheduled') {
        return e;
      }
    }
    return null;
  }

  Commitment? nextActivity() {
    final now = DateTime.now();
    final future = _commitments.where((e) => e.endsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return future.isEmpty ? null : future.first;
  }

  List<Commitment> todayAgenda() {
    final now = DateTime.now();
    return _commitments.where((e) {
      return e.startsAt.year == now.year && e.startsAt.month == now.month && e.startsAt.day == now.day;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  Future<void> _checkSchedule() async {
    final now = DateTime.now();

    for (final event in _commitments) {
      if (event.status == 'completed' || event.status == 'cancelled') continue;

      final startKey = 'start_${event.id}_${event.startsAt.toIso8601String()}';
      final startDiff = event.startsAt.difference(now).inSeconds;

      // Al llegar la hora: el asistente pregunta (voz + modal)
      if (startDiff <= 30 && startDiff >= -120 && event.status == 'scheduled') {
        if (!await _wasPrompted(startKey)) {
          await _markPrompted(startKey);
          await _promptStart(event);
        }
      }

      // 15 min antes: aviso por voz
      final warnKey = 'warn_${event.id}_${event.startsAt.toIso8601String()}';
      if (startDiff <= 900 && startDiff > 840 && event.status == 'scheduled') {
        if (!await _wasPrompted(warnKey)) {
          await _markPrompted(warnKey);
          final mins = (startDiff / 60).ceil();
          await speak(
            'Atención. En $mins minutos comienza ${event.title}, '
            'con ${event.company?.name ?? 'tu empresa'}.',
          );
        }
      }

      // Al terminar el horario: preguntar si completó
      final endKey = 'end_${event.id}_${event.endsAt.toIso8601String()}';
      final endDiff = event.endsAt.difference(now).inSeconds;
      if (endDiff <= 30 && endDiff >= -300 && event.status == 'in_progress') {
        if (!await _wasPrompted(endKey)) {
          await _markPrompted(endKey);
          await _promptComplete(event);
        }
      }
    }
  }

  Future<void> _promptStart(Commitment event) async {
    await speak(
      'Es hora de ${event.title}. '
      '¿Vas a iniciar la actividad o prefieres aplazarla?',
    );
    await _showPrompt(event);
  }

  Future<void> _promptComplete(Commitment event) async {
    await speak('Terminó el horario de ${event.title}. ¿La completaste?');
    await _showPrompt(event, completing: true);
  }

  Future<void> _showPrompt(Commitment event, {bool fromNotification = false, bool completing = false}) async {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;

    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      isDismissible: !fromNotification,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityPromptSheet(
        event: event,
        completing: completing,
        onStart: () async {
          Navigator.pop(context);
          await _onAction?.call(event.id, 'in_progress');
          await speak('Actividad iniciada. ¡Éxito!');
        },
        onPostpone: () async {
          Navigator.pop(context);
          await _onAction?.call(event.id, 'postpone_1h');
          await speak('Actividad aplazada una hora.');
        },
        onComplete: () async {
          Navigator.pop(context);
          await _onAction?.call(event.id, 'completed');
          await speak('Registrado como completado.');
        },
      ),
    );
  }

  Commitment? _find(int id) {
    for (final e in _commitments) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<bool> _wasPrompted(String key) async {
    if (_promptedKeys.contains(key)) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pda_prompt_$key') ?? false;
  }

  Future<void> _markPrompted(String key) async {
    _promptedKeys.add(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pda_prompt_$key', true);
  }

  static String payloadFor(Commitment c, String type) {
    return jsonEncode({'id': c.id, 'type': type, 'title': c.title});
  }
}
