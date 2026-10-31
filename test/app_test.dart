import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';

import 'helpers/test_app.dart';
import 'helpers/test_database.dart';

Finder navTab(String label) =>
    find.descendant(of: find.byType(HaraBottomNav), matching: find.text(label));

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<bool> pressBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

void main() {
  testWidgets('starts on Home in the saved theme mode', (tester) async {
    await pumpHaraApp(
      tester,
      prefs: {...onboardedPrefs, 'settings.themeMode': 'dark'},
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.text('Welcome to HaraPlay'), findsOneWidget);
    for (final label in ['Home', 'Library', 'Search', 'Playlists']) {
      expect(navTab(label), findsOneWidget);
    }
  });

  testWidgets('bottom nav switches between the four tabs', (tester) async {
    await pumpHaraApp(tester);

    await tapAndSettle(tester, navTab('Library'));
    expect(find.text('No music yet'), findsOneWidget);
    await tapAndSettle(tester, navTab('Search'));
    expect(find.text('Search your music'), findsOneWidget);
    await tapAndSettle(tester, navTab('Playlists'));
    expect(find.text('Your playlists'), findsOneWidget);
    await tapAndSettle(tester, navTab('Home'));
    expect(find.text('Welcome to HaraPlay'), findsOneWidget);
  });

  testWidgets('each tab keeps its own back stack', (tester) async {
    final db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(1, title: 'Night Drive', album: 'Midnight', albumId: 7),
    ]);
    await pumpHaraApp(tester, database: db);

    await tapAndSettle(tester, navTab('Library'));
    await tapAndSettle(tester, find.text('Albums'));
    await tapAndSettle(tester, find.text('Midnight'));
    expect(find.text('ALBUM'), findsOneWidget);

    await tapAndSettle(tester, navTab('Home'));
    expect(find.text('ALBUM'), findsNothing);
    await tapAndSettle(tester, navTab('Library'));
    expect(find.text('ALBUM'), findsOneWidget);

    // Re-selecting the current tab returns to its root.
    await tapAndSettle(tester, navTab('Library'));
    expect(find.text('ALBUM'), findsNothing);
    expect(find.text('1 album'), findsOneWidget);
  });

  testWidgets('Android back pops the tab, then returns Home, then exits', (
    tester,
  ) async {
    await pumpHaraApp(tester);
    await tapAndSettle(tester, navTab('Playlists'));
    await tapAndSettle(tester, find.text('Liked songs'));
    expect(find.text('No liked songs yet'), findsOneWidget);

    expect(await pressBack(tester), isTrue);
    expect(find.text('Your playlists'), findsOneWidget);

    expect(await pressBack(tester), isTrue);
    expect(find.text('Welcome to HaraPlay'), findsOneWidget);

    // On Home the app does not consume back, so Android closes it.
    expect(await pressBack(tester), isFalse);
  });

  testWidgets('Settings opens above the shell and changes the theme', (
    tester,
  ) async {
    await pumpHaraApp(tester);
    await tapAndSettle(tester, find.byTooltip('Settings'));

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.byType(HaraBottomNav), findsNothing);

    await tapAndSettle(tester, find.text('Dark'));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    expect(await pressBack(tester), isTrue);
    expect(find.text('Welcome to HaraPlay'), findsOneWidget);
    expect(find.byType(HaraBottomNav), findsOneWidget);
  });

  testWidgets('design gallery is reachable from Settings in debug', (
    tester,
  ) async {
    await pumpHaraApp(tester);
    await tapAndSettle(tester, find.byTooltip('Settings'));
    await tapAndSettle(tester, find.text('Design gallery'));
    expect(find.text('Colours'), findsOneWidget);
  });

  testWidgets('licenses page opens from Settings', (tester) async {
    await pumpHaraApp(tester);
    await tapAndSettle(tester, find.byTooltip('Settings'));
    await tapAndSettle(tester, find.text('Open-source licenses'));
    expect(find.textContaining('The HaraPlay Authors'), findsOneWidget);
  });
}
