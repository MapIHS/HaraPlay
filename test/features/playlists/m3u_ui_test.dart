import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/playlists/domain/m3u.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

const _music = '/storage/emulated/0/Music';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
  });

  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<AppDatabase> library() async {
    final db = createTestDatabase();
    await db.libraryDao.applyScan([
      mediaSong(1, path: '$_music/a.mp3', title: 'Alpha'),
      mediaSong(2, path: '$_music/b.mp3', title: 'Beta'),
    ]);
    return db;
  }

  Future<void> openPlaylistsTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(HaraBottomNav),
        matching: find.text('Playlists'),
      ),
    );
    await settleDb(tester);
  }

  testWidgets('importing an .m3u opens the new playlist and says how it went', (
    tester,
  ) async {
    final files = FakeDocumentFiles()
      ..toOpen = (
        name: 'Road Trip.m3u8',
        path: '$_music/Road Trip.m3u8',
        bytes: Uint8List.fromList(
          utf8.encode('#EXTM3U\nb.mp3\nmissing.mp3\na.mp3\n'),
        ),
      );
    await pumpHaraApp(tester, database: await library(), documentFiles: files);
    await openPlaylistsTab(tester);

    await tester.tap(find.byTooltip('Import playlist (.m3u)'));
    await settleDb(tester);
    expect(find.text('Road Trip'), findsWidgets); // the playlist page
    expect(
      find.text("Imported 2 of 3 songs; 1 isn't on this phone."),
      findsOneWidget,
    );
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('a playlist exports from its options', (tester) async {
    final db = await library();
    final id = await db.playlistsDao.create('Mix', at: DateTime(2026));
    await db.playlistsDao.addSongs(id, [2, 1], at: DateTime(2026));
    final files = FakeDocumentFiles();
    await pumpHaraApp(tester, database: db, documentFiles: files);
    await openPlaylistsTab(tester);

    await tester.tap(find.byTooltip('Playlist options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export as .m3u'));
    await settleDb(tester);
    expect(files.savedName, 'Mix.m3u');
    expect(parseM3u(files.savedText!), ['$_music/b.mp3', '$_music/a.mp3']);
    expect(find.text('Saved "Mix.m3u".'), findsOneWidget);
  });
}
