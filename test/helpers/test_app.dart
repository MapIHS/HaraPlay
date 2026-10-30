import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/app.dart';
import 'package:haraplay/core/platform/media_store_channel.dart';
import 'package:haraplay/core/storage/preferences.dart';
import 'package:haraplay/core/theme/hara_theme.dart';
import 'package:haraplay/features/onboarding/data/media_permission_service.dart';
import 'package:haraplay/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fakes.dart';

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

/// Preferences of a user who has finished onboarding.
const onboardedPrefs = <String, Object>{'onboarding.completed': true};

/// Pumps the whole app with fakes for the platform. By default the user has
/// granted access and finished onboarding, so the app opens on Home.
Future<void> pumpHaraApp(
  WidgetTester tester, {
  Map<String, Object> prefs = onboardedPrefs,
  MediaAccess initialAccess = MediaAccess.granted,
  FakeMediaPermissionService? permissions,
  FakeMediaSource? mediaSource,
  int sdkInt = 34,
}) async {
  final preferences = await createTestPreferences(prefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sdkIntProvider.overrideWithValue(sdkInt),
        initialMediaAccessProvider.overrideWithValue(initialAccess),
        mediaPermissionServiceProvider.overrideWithValue(
          permissions ?? FakeMediaPermissionService(status: initialAccess),
        ),
        mediaSourceProvider.overrideWithValue(mediaSource ?? FakeMediaSource()),
      ],
      child: const HaraPlayApp(),
    ),
  );
  await tester.pumpAndSettle();
}
