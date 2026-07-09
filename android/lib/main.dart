import 'package:flutter/material.dart';
import 'package:caraprojetada/models/user_prefs.dart';
import 'package:caraprojetada/services/api_service.dart';
import 'package:caraprojetada/services/prefs_service.dart';
import 'package:caraprojetada/services/vnc_service.dart';
import 'package:caraprojetada/screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefsService = await UserPrefsService.initialize();
  final prefs = prefsService.prefs;
  runApp(CaraProjetadaApp(prefs: prefs, prefsService: prefsService));
}

class CaraProjetadaApp extends StatelessWidget {
  final UserPrefs prefs;
  final UserPrefsService prefsService;

  const CaraProjetadaApp({
    super.key,
    required this.prefs,
    required this.prefsService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaraProjetada',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        prefs: prefs,
        prefsService: prefsService,
        api: ApiService(),
      ),
    );
  }
}
