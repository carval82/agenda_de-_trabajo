import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _prefKey = 'api_base_url';

  /// Producción Railway
  static const String railwayUrl = 'https://agendade-trabajo-production.up.railway.app/api';

  /// Opciones comunes según dónde corres la app
  static const presets = <String, String>{
    'Railway (producción)': railwayUrl,
    'Artisan (PC/emulador)': 'http://127.0.0.1:8000/api',
    'Artisan (Android emulador)': 'http://10.0.2.2:8000/api',
    'XAMPP local': 'http://127.0.0.1/agenda_de%20_trabajo/public/api',
  };

  static String _baseUrl = _defaultForPlatform();

  static String get baseUrl => _baseUrl;

  static String _defaultForPlatform() {
    // Producción en Railway; usa presets en ConnectionScreen para desarrollo local
    return railwayUrl;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefKey) ?? _defaultForPlatform();
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _baseUrl);
  }

  static String get healthUrl => '$baseUrl/health';
}
