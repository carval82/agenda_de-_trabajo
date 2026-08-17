import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  String? get token => _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': 'agenda_flutter',
      }),
    );

    final data = _decode(response) as Map<String, dynamic>;
    _token = data['token'] as String;
    return data;
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': 'agenda_flutter',
      }),
    );

    final data = _decode(response) as Map<String, dynamic>;
    _token = data['token'] as String;
    return data;
  }

  Future<AppUser> getMe() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/me'),
      headers: _headers,
    );
    final data = _decode(response) as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  Future<List<Company>> getCompanies() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/companies'),
      headers: _headers,
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((e) => Company.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Commitment>> getUpcoming() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/commitments/upcoming'),
      headers: _headers,
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((e) => Commitment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Commitment>> getCalendar(DateTime start, DateTime end) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/commitments/calendar').replace(
      queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
    );
    final response = await _client.get(uri, headers: _headers);
    final data = _decode(response) as List<dynamic>;

    return data.map((event) {
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
        recurringEventId: props['recurring_event_id'] as int?,
        isRecurring: props['is_recurring'] as bool? ?? false,
        company: Company(
          id: props['company_id'] as int,
          name: props['company'] as String,
          slug: props['company_slug'] as String,
          type: '',
          color: event['backgroundColor'] as String? ?? '#2563eb',
        ),
      );
    }).toList();
  }

  Future<String?> checkConflict(DateTime start, DateTime end, {int? excludeId}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/commitments/check-conflict'),
      headers: _headers,
      body: jsonEncode({
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': end.toUtc().toIso8601String(),
        if (excludeId != null) 'exclude_id': excludeId,
      }),
    );

    final data = _decode(response) as Map<String, dynamic>;
    if (data['has_conflict'] == true) {
      return data['message'] as String? ?? 'Conflicto de horario';
    }
    return null;
  }

  Future<Commitment> createCommitment(Commitment commitment) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/commitments'),
      headers: _headers,
      body: jsonEncode(commitment.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return Commitment.fromJson(data['commitment'] as Map<String, dynamic>);
  }

  Future<Commitment> updateCommitment(Commitment commitment) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/commitments/${commitment.id}'),
      headers: _headers,
      body: jsonEncode(commitment.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return Commitment.fromJson(data['commitment'] as Map<String, dynamic>);
  }

  Future<void> deleteCommitment(int id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/commitments/$id'),
      headers: _headers,
    );
    _decode(response);
  }

  Future<Commitment> updateStatus(int id, String status) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/commitments/$id/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return Commitment.fromJson(data['commitment'] as Map<String, dynamic>);
  }

  Future<Commitment> postponeCommitment(int id, DateTime start, DateTime end) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/commitments/$id/postpone'),
      headers: _headers,
      body: jsonEncode({
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': end.toUtc().toIso8601String(),
      }),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return Commitment.fromJson(data['commitment'] as Map<String, dynamic>);
  }

  Future<List<RecurringEvent>> getRecurringEvents() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/recurring-events'),
      headers: _headers,
    );
    final data = _decode(response) as List<dynamic>;
    return data.map((e) => RecurringEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RecurringEvent> createRecurringEvent(RecurringEvent event) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/recurring-events'),
      headers: _headers,
      body: jsonEncode(event.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return RecurringEvent.fromJson(data['recurring_event'] as Map<String, dynamic>);
  }

  Future<RecurringEvent> updateRecurringEvent(RecurringEvent event) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/recurring-events/${event.id}'),
      headers: _headers,
      body: jsonEncode(event.toJson()),
    );
    final data = _decode(response) as Map<String, dynamic>;
    return RecurringEvent.fromJson(data['recurring_event'] as Map<String, dynamic>);
  }

  Future<void> deleteRecurringEvent(int id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/recurring-events/$id'),
      headers: _headers,
    );
    _decode(response);
  }

  Future<void> generateRecurringEvents() async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/recurring-events/generate'),
      headers: _headers,
      body: jsonEncode({}),
    );
    _decode(response);
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? {} : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic>) {
      final errors = body['errors'];
      if (errors is Map<String, dynamic>) {
        final messages = errors.values
            .expand((value) => value is List ? value : [value])
            .map((value) => value.toString())
            .where((message) => message.isNotEmpty && message != 'validation.required')
            .toList();

        if (messages.isNotEmpty) {
          throw ApiException(messages.join('\n'), statusCode: response.statusCode);
        }
      }

      final message = _humanizeMessage(body['message'] as String? ?? 'Error de API');
      throw ApiException(message, statusCode: response.statusCode);
    }

    throw ApiException('Error de API', statusCode: response.statusCode);
  }

  String _humanizeMessage(String message) {
    const known = {
      'validation.required': 'Completa los campos obligatorios.',
      'The given data was invalid.': 'Revisa los datos del formulario.',
    };

    return known[message] ?? message;
  }
}
