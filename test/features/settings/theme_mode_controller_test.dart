import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/storage/preferences.dart';
import 'package:haraplay/features/settings/presentation/theme_mode_controller.dart';

import '../../helpers/test_app.dart';

void main() {
  test('defaults to following the system', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await createTestPreferences(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('persists the chosen mode across app launches', () async {
    final prefs = await createTestPreferences();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await first.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    expect(first.read(themeModeProvider), ThemeMode.dark);
    first.dispose();

    final relaunched = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(relaunched.dispose);
    expect(relaunched.read(themeModeProvider), ThemeMode.dark);
  });

  test('ignores unknown stored values', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await createTestPreferences({'settings.themeMode': 'sepia'}),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });
}
