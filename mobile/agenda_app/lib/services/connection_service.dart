import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ConnectionService {
  ConnectionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<bool> checkServer({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final health = Uri.parse(ApiConfig.healthUrl);
      final response = await _client.get(health).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      // Fallback: probar endpoint público de login (OPTIONS/GET puede fallar, POST ligero)
      try {
        final ping = Uri.parse('${ApiConfig.baseUrl}/login');
        final response = await _client
            .post(
              ping,
              headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
              body: '{}',
            )
            .timeout(timeout);
        // 422 = servidor responde (validación), 401/405 también indican que hay servidor
        return response.statusCode < 500;
      } catch (_) {
        return false;
      }
    }
  }
}
