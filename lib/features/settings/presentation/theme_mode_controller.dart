import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

/// The user's theme mode (system / light / dark), persisted across launches.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(settingsRepositoryProvider).readThemeMode();

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(settingsRepositoryProvider).writeThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
