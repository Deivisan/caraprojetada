import 'package:flutter/material.dart';
import '../models/user_prefs.dart';
import '../services/prefs_service.dart';
import 'home_screen.dart';

class SettingsScreen extends StatelessWidget {
  final UserPrefs prefs;
  final UserPrefsService prefsService;

  const SettingsScreen({
    super.key,
    required this.prefs,
    required this.prefsService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracoes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.rotate_left),
            title: const Text('Refazer onboarding'),
            subtitle: const Text('Selecionar modo de uso novamente'),
            onTap: () async {
              await prefsService.clear();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(
                      prefs: const UserPrefs(),
                      prefsService: prefsService,
                      api: ApiService(),
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Sobre'),
            subtitle: const Text('CaraProjetada v1.0.0'),
          ),
        ],
      ),
    );
  }
}
