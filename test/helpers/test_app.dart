import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/storage/preferences.dart';
import 'package:haraplay/core/theme/hara_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Preferences backed by an in-memory store, optionally pre-filled.
Future<SharedPreferencesWithCache> createTestPreferences([
  Map<String, Object> initial = const {},
]) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(Map.of(initial));
  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
}

extension PumpHara on WidgetTester {
  /// Pumps [child] inside a themed [MaterialApp] and a [ProviderScope].
  Future<void> pumpHara(
    Widget child, {
    ThemeData? theme,
    SharedPreferencesWithCache? preferences,
  }) async {
    final prefs = preferences ?? await createTestPreferences();
    await pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: theme ?? HaraTheme.light,
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}
