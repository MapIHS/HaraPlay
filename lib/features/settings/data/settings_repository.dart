import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/theme/palettes.dart';

/// Persists user settings in shared preferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _themeModeKey = 'settings.themeMode';
  static const _colorChoiceKey = 'settings.colorChoice';
  static const _excludedFoldersKey = 'library.excludedFolders';
  static const _minSongLengthKey = 'settings.minSongLengthSeconds';

  /// Choices for the minimum song length; [Duration.zero] means "off".
  static const minSongLengthOptions = [
    Duration.zero,
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  static const defaultMinSongLength = Duration(seconds: 30);

  ThemeMode readThemeMode() {
    final stored = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> writeThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);

  ColorChoice readColorChoice() {
    final stored = _prefs.getString(_colorChoiceKey);
    return ColorChoice.values.firstWhere(
      (choice) => choice.name == stored,
      orElse: () => ColorChoice.saffron,
    );
  }

  Future<void> writeColorChoice(ColorChoice choice) =>
      _prefs.setString(_colorChoiceKey, choice.name);

  /// Folders (absolute paths) whose songs are hidden, subfolders included.
  List<String> readExcludedFolders() =>
      _prefs.getStringList(_excludedFoldersKey) ?? const [];

  Future<void> writeExcludedFolders(List<String> folders) =>
      _prefs.setStringList(_excludedFoldersKey, folders);

  /// Songs shorter than this are hidden from the library (not deleted).
  Duration readMinSongLength() {
    final seconds = _prefs.getInt(_minSongLengthKey);
    final stored = seconds == null ? null : Duration(seconds: seconds);
    return minSongLengthOptions.contains(stored)
        ? stored!
        : defaultMinSongLength;
  }

  Future<void> writeMinSongLength(Duration length) =>
      _prefs.setInt(_minSongLengthKey, length.inSeconds);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);
