import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_widgets.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'pcapacho24@gmail.com');
  final _password = TextEditingController(text: 'anaval33');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgendaProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF060B14), Color(0xFF0A1220), Color(0xFF060B14)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const PdaLogo(),
                    const SizedBox(height: 24),
                    const Text('Agenda de Trabajo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'LC Design · Interveredanet.cr',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.panel.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _feature(Icons.calendar_month, 'Calendario organizado'),
                          _feature(Icons.block, 'Sin cruces de horario'),
                          _feature(Icons.notifications_active, 'Recordatorios PDA'),
                          const SizedBox(height: 20),
                          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          TextField(controller: _password, decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)), obscureText: true),
                          if (provider.error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                              child: Text(provider.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: provider.loading
                                ? null
                                : () async {
                                    await provider.login(_email.text.trim(), _password.text);
                                    if (context.mounted && provider.error == null) {
                                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
                                    }
                                  },
                            child: Text(provider.loading ? 'Entrando...' : 'Entrar a la agenda'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.lcdesign),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
