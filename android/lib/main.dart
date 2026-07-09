import 'package:flutter/material.dart';
import 'package:caraprojetada/models/user_prefs.dart';
import 'package:caraprojetada/services/api_service.dart';
import 'package:caraprojetada/services/prefs_service.dart';
import 'package:caraprojetada/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefsService = await UserPrefsService.initialize();
  final prefs = prefsService.prefs;
  final api = ApiService();
  runApp(
    CaraProjetadaApp(
      prefs: prefs,
      prefsService: prefsService,
      api: api,
    ),
  );
}

class CaraProjetadaApp extends StatelessWidget {
  final UserPrefs prefs;
  final UserPrefsService prefsService;
  final ApiService api;

  const CaraProjetadaApp({
    super.key,
    required this.prefs,
    required this.prefsService,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaraProjetada',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: HomeScreen(
        prefs: prefs,
        prefsService: prefsService,
        api: api,
      ),
    );
  }

  ThemeData _buildTheme() {
    const primary = Color(0xFF003366);
    const accent = Color(0xFF005580);
    const purple = Color(0xFF6A1B9A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        tertiary: purple,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
