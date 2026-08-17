import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import 'pda_assistant_service.dart';

/// Consultas API usables desde el servicio en segundo plano (sin Provider).
class AssistantRemote {
  AssistantRemote._();

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> cacheUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  static Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<Commitment>> fetchActiveCommitments() async {
    final token = await _token();
    if (token == null) return [];

    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final end = now.add(const Duration(days: 30));

      final calendarUri = Uri.parse('${ApiConfig.baseUrl}/commitments/calendar').replace(
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final upcomingUri = Uri.parse('${ApiConfig.baseUrl}/commitments/upcoming');

      final results = await Future.wait([
        http.get(calendarUri, headers: _headers(token)),
        http.get(upcomingUri, headers: _headers(token)),
      ]);

      final map = <int, Commitment>{};

      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body) as List<dynamic>;
        for (final event in data) {
          final c = _fromCalendarEvent(event as Map<String, dynamic>);
          map[c.id] = c;
        }
      }

      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body) as List<dynamic>;
        for (final item in data) {
          final c = Commitment.fromJson(item as Map<String, dynamic>);
          map[c.id] = c;
        }
      }

      return map.values.toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Commitment>> fetchTodayCommitments() async {
    final all = await fetchActiveCommitments();
    final now = DateTime.now();
    return all.where((e) {
      return e.startsAt.year == now.year && e.startsAt.month == now.month && e.startsAt.day == now.day;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  static Future<void> syncAssistantCache() async {
    final all = await fetchActiveCommitments();
    PdaAssistantService.instance.updateCommitments(all);
    final prefs = await SharedPreferences.getInstance();
    PdaAssistantService.instance.userName = prefs.getString('user_name');
    final today = await fetchTodayCommitments();
    await PdaAssistantService.instance.evaluateDayModeFromEvents(today);
  }

  static Future<List<Company>> fetchCompanies() async {
    final token = await _token();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/companies'),
        headers: _headers(token),
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Company.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Retorna null si OK, o mensaje de error.
  static Future<String?> createCommitment(Commitment commitment) async {
    final token = await _token();
    if (token == null) return 'Sin sesión activa';

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/commitments'),
        headers: _headers(token),
        body: jsonEncode(commitment.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await syncAssistantCache();
        return null;
      }

      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
      return 'Error al guardar el compromiso';
    } catch (e) {
      return e.toString();
    }
  }

  static Commitment _fromCalendarEvent(Map<String, dynamic> event) {
    final props = event['extendedProps'] as Map<String, dynamic>? ?? {};
    return Commitment(
      id: event['id'] as int,
      companyId: props['company_id'] as int,
      title: event['title'] as String,
      startsAt: DateTime.parse(event['start'] as String).toLocal(),
      endsAt: DateTime.parse(event['end'] as String).toLocal(),
      description: props['description'] as String?,
      location: props['location'] as String?,
      clientName: props['client_name'] as String?,
      priority: props['priority'] as String? ?? 'medium',
      status: props['status'] as String? ?? 'scheduled',
      company: Company(
        id: props['company_id'] as int,
        name: props['company'] as String,
        slug: props['company_slug'] as String,
        type: '',
        color: event['backgroundColor'] as String? ?? '#2563eb',
      ),
    );
  }
}
