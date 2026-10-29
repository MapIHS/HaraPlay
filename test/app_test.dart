import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/app.dart';
import 'package:haraplay/core/storage/preferences.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('app starts in the saved theme mode', (tester) async {
    final prefs = await createTestPreferences({'settings.themeMode': 'dark'});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const HaraPlayApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.text('Design gallery'), findsOneWidget);
  });

  testWidgets('switching theme in the gallery updates the app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await createTestPreferences(),
          ),
        ],
        child: const HaraPlayApp(),
      ),
    );

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });
}
