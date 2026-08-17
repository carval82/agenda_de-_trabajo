import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_prompt_sheet.dart';

class PdaAssistantService {
  PdaAssistantService._();
  static final PdaAssistantService instance = PdaAssistantService._();

  static const int morningHour = 7;
  static const int morningMinute = 0;

  final FlutterTts _tts = FlutterTts();
  Timer? _watchTimer;
  GlobalKey<NavigatorState>? _navigatorKey;
  Future<void> Function(int id, String action)? _onAction;
  VoidCallback? onDayModeChanged;
  List<Commitment> _commitments = [];
  final Set<String> _promptedKeys = {};
  bool _ttsReady = false;
  DayMode dayMode = DayMode.pending;
  String? userName;

  Future<void> init() async {
    if (_ttsReady) return;
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ttsReady = true;
    await _loadDayMode();
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

  Future<void> setDayMode(DayMode mode) async {
    dayMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pda_day_mode', mode.name);
    await prefs.setString('pda_day_mode_date', _todayKey());
    onDayModeChanged?.call();
  }

  Future<void> _loadDayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('pda_day_mode_date');
    final savedMode = prefs.getString('pda_day_mode');
    if (savedDate == _todayKey() && savedMode != null) {
      dayMode = DayMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => DayMode.pending,
      );
    } else {
      dayMode = DayMode.pending;
    }
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<bool> morningBriefingDoneToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('morning_briefing_${_todayKey()}') ?? false;
  }

  Future<void> _markMorningBriefingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_briefing_${_todayKey()}', true);
  }

  /// Si hoy no hay eventos activos → modo reposo. Si hay → día activo.
  Future<void> evaluateDayModeFromEvents(List<Commitment> todayEvents) async {
    await init();
    final active = todayEvents
        .where((e) => e.status != 'completed' && e.status != 'cancelled')
        .toList();

    if (active.isEmpty) {
      if (dayMode != DayMode.rest) {
        await setDayMode(DayMode.rest);
      }
    } else if (dayMode == DayMode.rest || dayMode == DayMode.pending) {
      await setDayMode(DayMode.active);
    }
  }

  /// Rutina de las 7:00 — pregunta qué hay hoy y activa modo reposo o día activo.
  Future<void> runMorningRoutine(List<Commitment> todayEvents, {String? name}) async {
    await init();
    userName = name ?? userName;
    final greeting = _greeting();
    final firstName = _firstName(userName);

    final activeToday = todayEvents
        .where((e) => e.status != 'completed' && e.status != 'cancelled')
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (activeToday.isEmpty) {
      await setDayMode(DayMode.rest);
      await speak(
        '$greeting${firstName.isNotEmpty ? ', $firstName' : ''}. '
        'Revisé tu agenda: no tienes nada programado para hoy. '
        'Activo modo reposo. Descansa o agenda algo cuando quieras.',
      );
    } else {
      await setDayMode(DayMode.active);
      final count = activeToday.length;
      final fmt = DateFormat('HH:mm');
      final lines = activeToday.take(5).map((e) {
        final company = e.company?.name ?? '';
        return '${fmt.format(e.startsAt)} ${e.title}${company.isNotEmpty ? ' con $company' : ''}';
      }).join('. ');

      final more = count > 5 ? ' Y ${count - 5} actividades más.' : '';
      await speak(
        '$greeting${firstName.isNotEmpty ? ', $firstName' : ''}. '
        'Hoy tienes $count ${count == 1 ? 'actividad' : 'actividades'}. '
        '$lines.$more '
        'Programo tu día y te aviso a cada hora.',
      );
    }

    await _markMorningBriefingDone();
  }

  Future<void> dailyBriefing(List<Commitment> todayEvents) async {
    await runMorningRoutine(todayEvents, name: userName);
  }

  /// Si son las 7:00 y aún no hubo briefing, lo ejecuta (respaldo si falló la notificación).
  Future<void> checkMorningIfNeeded(List<Commitment> todayEvents) async {
    final now = DateTime.now();
    if (await morningBriefingDoneToday()) return;
    if (now.hour < morningHour || (now.hour == morningHour && now.minute < morningMinute)) return;
    await runMorningRoutine(todayEvents, name: userName);
  }

  Future<String> processVoiceCommand(String raw) async {
    final text = raw.toLowerCase().trim();
    if (text.isEmpty) {
      const msg = 'No te escuché bien. Intenta de nuevo.';
      await speak(msg);
      return msg;
    }

    if (_matches(text, ['ayuda', 'comandos', 'qué puedo decir'])) {
      const msg =
          'Puedes decir: qué tengo hoy, estado, próximo, modo reposo, '
          'o agendar seguido del compromiso. Por ejemplo: agenda reunión mañana a las tres de la tarde con LC Design.';
      await speak(msg);
      return msg;
    }

    if (_matches(text, ['modo reposo', 'activar reposo', 'descansar', 'día libre'])) {
      await setDayMode(DayMode.rest);
      const msg = 'Modo reposo activado. Disfruta tu día.';
      await speak(msg);
      return msg;
    }

    if (_matches(text, ['estado', 'cómo voy', 'en curso', 'actividad actual', 'qué estoy haciendo'])) {
      final current = currentActivity();
      if (current != null) {
        final msg =
            'Ahora: ${current.title}, ${statusLabel(current.status)}, hasta las ${DateFormat('HH:mm').format(current.endsAt)}.';
        await speak(msg);
        return msg;
      }
      final next = nextActivity();
      if (next != null) {
        final msg =
            'No hay nada en curso. Próximo: ${next.title} a las ${DateFormat('HH:mm').format(next.startsAt)}.';
        await speak(msg);
        return msg;
      }
      const msg = 'No tienes actividades pendientes.';
      await speak(msg);
      return msg;
    }

    if (_matches(text, ['próximo', 'siguiente', 'qué sigue'])) {
      final next = nextActivity();
      if (next != null) {
        final msg = 'Tu próximo compromiso es ${next.title}, a las ${DateFormat('HH:mm').format(next.startsAt)}.';
        await speak(msg);
        return msg;
      }
      const msg = 'No hay más actividades programadas.';
      await speak(msg);
      return msg;
    }

    if (_matches(text, [
      'qué tengo hoy',
      'agenda de hoy',
      'mis actividades',
      'compromisos de hoy',
      'qué hay para hoy',
      'mi día',
    ])) {
      final today = todayAgenda();
      await runMorningRoutine(today, name: userName);
      return dayMode == DayMode.rest ? 'Modo reposo — sin actividades hoy.' : 'Agenda del día leída.';
    }

    const msg = 'No entendí. Di ayuda para ver los comandos disponibles.';
    await speak(msg);
    return msg;
  }

  bool _matches(String text, List<String> phrases) {
    return phrases.any((p) => text.contains(p));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _firstName(String? name) {
    if (name == null || name.isEmpty) return '';
    return name.split(' ').first;
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

    // Respaldo: briefing matutino cerca de las 7:00
    if (now.hour == morningHour && now.minute <= 5 && !await morningBriefingDoneToday()) {
      final key = 'morning_watch_${_todayKey()}';
      if (!await _wasPrompted(key)) {
        await _markPrompted(key);
        await runMorningRoutine(todayAgenda(), name: userName);
      }
    }

    for (final event in _commitments) {
      if (event.status == 'completed' || event.status == 'cancelled') continue;

      final startKey = 'start_${event.id}_${event.startsAt.toIso8601String()}';
      final startDiff = event.startsAt.difference(now).inSeconds;

      if (startDiff <= 30 && startDiff >= -120 && event.status == 'scheduled') {
        if (!await _wasPrompted(startKey)) {
          await _markPrompted(startKey);
          await setDayMode(DayMode.active);
          await _promptStart(event);
        }
      }

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
