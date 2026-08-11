import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/connection_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_widgets.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, required this.onConnected});

  final VoidCallback onConnected;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _connection = ConnectionService();
  final _urlController = TextEditingController();
  bool _checking = false;
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiConfig.baseUrl;
    _check();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final ok = await _connection.checkServer();
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) widget.onConnected();
  }

  Future<void> _saveAndRetry() async {
    await ApiConfig.setBaseUrl(_urlController.text.trim());
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const AppLogo(variant: AppLogoVariant.hero, height: 160),
                  const SizedBox(height: 16),
                  Text(
                    'Sin conexión',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.intervereda,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No se pudo conectar al servidor.\nVerifica que Laravel esté corriendo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('URL del servidor', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            hintText: 'http://127.0.0.1:8000/api',
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedPreset,
                          decoration: const InputDecoration(labelText: 'Preset rápido'),
                          items: ApiConfig.presets.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.key, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (key) {
                            if (key == null) return;
                            setState(() {
                              _selectedPreset = key;
                              _urlController.text = ApiConfig.presets[key]!;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. En tu PC: php artisan serve --host=0.0.0.0\n2. Emulador Android: 10.0.2.2:8000\n3. Celular físico: IP de tu PC',
                          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _checking ? null : _saveAndRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.intervereda,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text(_checking ? 'Conectando...' : 'Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
