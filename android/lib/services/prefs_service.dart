import 'package:flutter/material.dart';
import 'package:caraprojetada/models/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPrefsService {
  static const String _key = 'caraprojetada_prefs';
  final SharedPreferences _prefs;

  UserPrefsService._(this._prefs);

  static Future<UserPrefsService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return UserPrefsService._(prefs);
  }

  UserPrefs get prefs {
    final json = _prefs.getString(_key);
    if (json != null) {
      try {
        return UserPrefs.fromJson(
          Map<String, dynamic>.from(jsonDecode(json) as Map),
        );
      } catch (_) {}
    }
    return const UserPrefs();
  }

  Future<void> save(UserPrefs prefs) async {
    await _prefs.setString(_key, jsonEncode(prefs.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
