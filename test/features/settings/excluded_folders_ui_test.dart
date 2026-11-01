import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/settings/presentation/excluded_folders_screen.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

const _root = '/storage/emulated/0';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('excluding a folder hides its songs at once; including it '
      'brings them back', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final AppDatabase db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(1, path: '$_root/Music/a.mp3'),
      mediaSong(2, path: '$_root/Music/Voice/b.mp3'),
      mediaSong(3, path: '$_root/Music/Voice/c.mp3'),
    ]);
    await pumpHaraApp(tester, database: db);
    await settle(tester);
    expect(find.text('3'), findsOneWidget); // the Songs chip

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('None: music from every folder is shown'), findsOneWidget);
    await tester.tap(find.text('Excluded folders'));
    await tester.pumpAndSettle();
    expect(find.byType(ExcludedFoldersScreen), findsOneWidget);
    expect(find.text('No excluded folders'), findsOneWidget);

    await tester.tap(find.text('Add folder'));
    await settle(tester);
    // Music (3 songs) and its subfolder Voice (2 songs).
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    await tester.tap(find.text('Voice'));
    await settle(tester);
    expect(find.text('Music/Voice'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Music/Voice'), findsOneWidget); // tile subtitle
    await tester.pageBack();
    await settle(tester);
    expect(find.text('SONG'), findsOneWidget); // "1 SONG"

    // Include it again.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluded folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Include Music/Voice again'));
    await settle(tester);
    expect(find.text('No excluded folders'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await settle(tester);
    expect(find.text('3'), findsOneWidget);
  });
}
