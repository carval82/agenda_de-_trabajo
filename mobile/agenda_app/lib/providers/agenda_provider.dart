import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/assistant_remote.dart';
import '../services/background_assistant_service.dart';
import '../services/pda_assistant_service.dart';
import '../services/reminder_service.dart';
import '../services/voice_service.dart';

class AgendaProvider extends ChangeNotifier {
  AgendaProvider(this._api);

  final ApiService _api;

  bool loading = false;
  String? error;
  AppUser? user;
  List<Company> companies = [];
  List<Commitment> upcoming = [];
  List<Commitment> calendarEvents = [];
  Set<int> visibleCompanies = {};
  bool backgroundAssistantEnabled = false;
  List<RecurringEvent> recurringEvents = [];

  DayMode get dayMode => PdaAssistantService.instance.dayMode;

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return false;
    _api.setToken(token);
    try {
      await loadData();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _api.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _api.token!);
      user = data['user'] != null ? AppUser.fromJson(data['user'] as Map<String, dynamic>) : null;
      if (user != null) await AssistantRemote.cacheUserName(user!.name);
      await loadData();
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String password, String passwordConfirmation) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _api.register(name, email, password, passwordConfirmation);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _api.token!);
      user = data['user'] != null ? AppUser.fromJson(data['user'] as Map<String, dynamic>) : null;
      if (user != null) await AssistantRemote.cacheUserName(user!.name);
      await loadData();
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await BackgroundAssistantService.instance.setEnabled(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _api.setToken(null);
    user = null;
    companies = [];
    upcoming = [];
    calendarEvents = [];
    notifyListeners();
  }

  Future<void> loadData() async {
    loading = true;
    notifyListeners();

    try {
      user = await _api.getMe();
      PdaAssistantService.instance.userName = user?.name;
      if (user != null) await AssistantRemote.cacheUserName(user!.name);

      companies = await _api.getCompanies();
      visibleCompanies = companies.map((c) => c.id).toSet();
      upcoming = await _api.getUpcoming();
      await loadCalendar(
        DateTime.now().subtract(const Duration(days: 7)),
        DateTime.now().add(const Duration(days: 30)),
      );

      for (final item in upcoming) {
        await ReminderService.instance.scheduleForCommitment(item);
      }

      await ReminderService.instance.scheduleDailyMorningBriefing(
        hour: PdaAssistantService.morningHour,
        minute: PdaAssistantService.morningMinute,
      );

      await _api.generateRecurringEvents();
      await loadRecurringEvents();

      _syncAssistant();
      await PdaAssistantService.instance.evaluateDayModeFromEvents(todayAgenda());
      await runMorningCheckIfNeeded();
      backgroundAssistantEnabled = await BackgroundAssistantService.instance.isEnabled();
      await BackgroundAssistantService.instance.ensureStartedIfEnabled();
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> runMorningCheckIfNeeded() async {
    await PdaAssistantService.instance.checkMorningIfNeeded(todayAgenda());
    notifyListeners();
  }

  Future<void> runMorningRoutine() async {
    await PdaAssistantService.instance.runMorningRoutine(todayAgenda(), name: user?.name);
    notifyListeners();
  }

  Future<void> refreshAssistantState() async {
    await PdaAssistantService.instance.evaluateDayModeFromEvents(todayAgenda());
    notifyListeners();
  }

  Future<void> loadRecurringEvents() async {
    try {
      recurringEvents = await _api.getRecurringEvents();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> saveRecurringEvent(RecurringEvent event) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _api.createRecurringEvent(event);
      await _api.generateRecurringEvents();
      await loadData();
      return null;
    } catch (e) {
      error = _friendlyError(e);
      return error;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> updateRecurringEvent(RecurringEvent event) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _api.updateRecurringEvent(event);
      await _api.generateRecurringEvents();
      await loadData();
      return null;
    } catch (e) {
      error = _friendlyError(e);
      return error;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> deleteRecurringEvent(int id) async {
    loading = true;
    notifyListeners();
    try {
      await _api.deleteRecurringEvent(id);
      await loadRecurringEvents();
      await loadData();
      return null;
    } catch (e) {
      error = _friendlyError(e);
      return error;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setBackgroundAssistant(bool enabled) async {
    if (enabled) {
      final mic = await VoiceService.instance.ensureMicrophonePermission();
      if (!mic) {
        error = 'Se necesita permiso de micrófono para el asistente en segundo plano.';
        notifyListeners();
        return;
      }
    }

    backgroundAssistantEnabled = enabled;
    notifyListeners();
    await BackgroundAssistantService.instance.setEnabled(enabled);
    notifyListeners();
  }

  Future<void> loadCalendar(DateTime start, DateTime end) async {
    calendarEvents = await _api.getCalendar(start, end);
    notifyListeners();
  }

  List<Commitment> eventsForDay(DateTime day) {
    return calendarEvents.where((event) {
      if (!visibleCompanies.contains(event.companyId)) return false;
      return event.startsAt.year == day.year &&
          event.startsAt.month == day.month &&
          event.startsAt.day == day.day;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  void toggleCompany(int id) {
    if (visibleCompanies.contains(id)) {
      if (visibleCompanies.length > 1) visibleCompanies.remove(id);
    } else {
      visibleCompanies.add(id);
    }
    notifyListeners();
  }

  Future<String?> saveCommitment(Commitment commitment, {int? editingId}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final conflict = await _api.checkConflict(
        commitment.startsAt,
        commitment.endsAt,
        excludeId: editingId,
      );
      if (conflict != null) {
        error = conflict;
        return conflict;
      }

      Commitment saved;
      if (editingId != null) {
        saved = await _api.updateCommitment(commitment);
      } else {
        saved = await _api.createCommitment(commitment);
      }

      await ReminderService.instance.scheduleForCommitment(saved);
      await loadData();
      return null;
    } catch (e) {
      error = _friendlyError(e);
      return error;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCommitment(int id) async {
    await _api.deleteCommitment(id);
    await ReminderService.instance.cancelForCommitment(id);
    await loadData();
  }

  List<Commitment> todayAgenda() {
    final now = DateTime.now();
    return calendarEvents.where((e) {
      if (!visibleCompanies.contains(e.companyId)) return false;
      return e.startsAt.year == now.year && e.startsAt.month == now.month && e.startsAt.day == now.day;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  void _syncAssistant() {
    final map = <int, Commitment>{};
    for (final e in calendarEvents) {
      map[e.id] = e;
    }
    for (final e in upcoming) {
      map[e.id] = e;
    }
    PdaAssistantService.instance.updateCommitments(map.values.toList());
  }

  Future<void> handleAssistantAction(int id, String action) async {
    if (action == 'postpone_1h') {
      Commitment? event;
      for (final e in [...upcoming, ...calendarEvents]) {
        if (e.id == id) {
          event = e;
          break;
        }
      }
      if (event == null) return;
      final start = DateTime.now().add(const Duration(hours: 1));
      final duration = event.endsAt.difference(event.startsAt);
      await postponeCommitment(event, start, start.add(duration));
      return;
    }

    final status = action == 'in_progress' ? 'in_progress' : action;
    if (['in_progress', 'completed', 'cancelled', 'scheduled'].contains(status)) {
      await setStatus(id, status);
    }
  }

  Future<String?> setStatus(int id, String status) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final saved = await _api.updateStatus(id, status);
      if (status == 'completed' || status == 'cancelled') {
        await ReminderService.instance.cancelForCommitment(id);
      } else {
        await ReminderService.instance.scheduleForCommitment(saved);
      }
      await loadData();
      return null;
    } catch (e) {
      error = _friendlyError(e);
      return error;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> postponeCommitment(Commitment event, DateTime newStart, DateTime newEnd) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final saved = await _api.postponeCommitment(event.id, newStart, newEnd);
      await ReminderService.instance.scheduleForCommitment(saved);
      await loadData();
      return null;
    } catch (e) {
      error = _friendlyError(e);
      return error;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Connection refused')) {
      return 'Sin conexión al servidor. Verifica tu internet o el servidor.';
    }
    return msg;
  }
}
