import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';

/// Persists user settings in shared preferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _themeModeKey = 'settings.themeMode';

  ThemeMode readThemeMode() {
    final stored = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> writeThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);
