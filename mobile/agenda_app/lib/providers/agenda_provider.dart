import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/reminder_service.dart';

class AgendaProvider extends ChangeNotifier {
  AgendaProvider(this._api);

  final ApiService _api;

  bool loading = false;
  String? error;
  List<Company> companies = [];
  List<Commitment> upcoming = [];
  List<Commitment> calendarEvents = [];
  Set<int> visibleCompanies = {};

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
      await _api.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _api.token!);
      await loadData();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Connection refused')) {
        error = 'Sin conexión al servidor. Verifica que Laravel esté corriendo.';
      } else {
        error = msg;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _api.setToken(null);
    companies = [];
    upcoming = [];
    calendarEvents = [];
    notifyListeners();
  }

  Future<void> loadData() async {
    loading = true;
    notifyListeners();

    try {
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
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Connection refused')) {
        error = 'Sin conexión al servidor. Verifica que Laravel esté corriendo.';
      } else {
        error = msg;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
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
      error = e.toString();
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
}
