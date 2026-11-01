import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/theme/hara_colors.dart';
import 'package:haraplay/core/theme/palettes.dart';
import 'package:haraplay/features/backup/data/backup_service.dart';
import 'package:haraplay/features/backup/domain/backup.dart';
import 'package:haraplay/features/backup/presentation/backup_settings.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

const _music = '/storage/emulated/0/Music';

Future<AppDatabase> _library(List<(int, String)> songs) async {
  final db = createTestDatabase();
  await db.libraryDao.applyScan([
    for (final (id, path) in songs)
      mediaSong(id, path: path, title: 'Song $id', sizeBytes: 1000 + id),
  ]);
  return db;
}

Future<void> _play(AppDatabase db, int songId, String path, int at) => db
    .into(db.playEvents)
    .insert(
      PlayEventsCompanion.insert(
        songId: Value(songId),
        songPath: path,
        title: 'Song $songId',
        startedAt: at,
        listenedMs: 60000,
        durationMs: 180000,
        completed: true,
        source: PlaySource.album,
      ),
    );

/// A phone with likes, a playlist, history and settings.
Future<(AppDatabase, BackupService)> _oldPhone() async {
  final db = await _library([
    (1, '$_music/a.mp3'),
    (2, '$_music/b.mp3'),
    (3, '$_music/c.mp3'),
  ]);
  await db.favoritesDao.setLiked(2, liked: true, at: DateTime(2026, 5));
  final mix = await db.playlistsDao.create('Mix', at: DateTime(2026, 6));
  await db.playlistsDao.addSongs(mix, [3, 1, 3], at: DateTime(2026, 6));
  await _play(db, 1, '$_music/a.mp3', 1000);
  await _play(db, 3, '$_music/c.mp3', 2000);
  // A song deleted since: its play has no song any more.
  await db
      .into(db.playEvents)
      .insert(
        PlayEventsCompanion.insert(
          songPath: '$_music/gone.mp3',
          title: 'Gone',
          artist: const Value('Old Band'),
          startedAt: 500,
          listenedMs: 30000,
          durationMs: 90000,
          completed: false,
          source: PlaySource.songs,
        ),
      );
  final prefs = await createTestPreferences({
    'settings.colorChoice': 'apricot',
    'playback.speed': 1.25,
    'playback.crossfadeSeconds': 6,
    'library.excludedFolders': ['$_music/Voice'],
    'onboarding.completed': true,
  });
  return (
    db,
    BackupService(
      db,
      prefs,
      FakeDocumentFiles(),
      clock: () => DateTime(2026, 11, 1),
    ),
  );
}

void main() {
  test('a backup survives the round trip through its file', () async {
    final (db, service) = await _oldPhone();
    addTearDown(db.close);
    final backup = Backup.decode((await service.collect()).encode());

    expect(backup.likes.single.song.path, '$_music/b.mp3');
    expect(backup.playlists.single.name, 'Mix');
    expect(backup.playlists.single.entries.map((e) => e.song.path), [
      '$_music/c.mp3',
      '$_music/a.mp3',
      '$_music/c.mp3',
    ]);
    expect(backup.plays.map((p) => p.song.title), ['Gone', 'Song 1', 'Song 3']);
    expect(backup.plays.first.song.artist, 'Old Band');
    expect(backup.settings, {
      'settings.colorChoice': 'apricot',
      'playback.speed': 1.25,
      'playback.crossfadeSeconds': 6,
      'library.excludedFolders': ['$_music/Voice'],
    }, reason: 'device state like onboarding stays out');
  });

  test('other files are refused', () {
    expect(() => Backup.decode('not json'), throwsFormatException);
    expect(() => Backup.decode('{"a": 1}'), throwsFormatException);
    expect(
      () => Backup.decode('{"format": "haraplay-backup", "version": 99}'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Made by a newer HaraPlay',
        ),
      ),
    );
    expect(
      () => Backup.decode(
        '{"format": "haraplay-backup", "version": 1, "likes": [{"x": 1}]}',
      ),
      throwsFormatException,
    );
  });

  group('restoring', () {
    test('into a fresh install: everything comes back, also when files '
        'moved folders', () async {
      final (old, oldService) = await _oldPhone();
      addTearDown(old.close);
      final backup = await oldService.collect();

      // The new install: c.mp3 moved to another folder; same file size.
      final db = await _library([
        (11, '$_music/a.mp3'),
        (12, '$_music/b.mp3'),
        (13, '/storage/emulated/0/Download/c.mp3'),
      ]);
      addTearDown(db.close);
      // Same sizes as on the old phone.
      await (db.update(db.songs)..where((s) => s.id.equals(13))).write(
        const SongsCompanion(sizeBytes: Value(1003)),
      );
      final prefs = await createTestPreferences();
      final service = BackupService(db, prefs, FakeDocumentFiles());

      final report = await service.restore(backup, settings: true);
      expect(report.likesAdded, 1);
      expect(report.playlistsAdded, 1);
      expect(report.playsAdded, 3);
      expect(report.missingSongs, 1, reason: 'gone.mp3');
      expect(report.settingsRestored, isTrue);

      expect((await db.select(db.favorites).get()).map((f) => f.songId), [12]);
      final playlist = (await db.playlistsDao.watchPlaylists().first).single;
      expect(playlist.name, 'Mix');
      final entries = await db.playlistsDao.watchEntries(playlist.id).first;
      expect(entries.map((e) => e.song.id), [13, 11, 13]);
      final plays = await (db.select(
        db.playEvents,
      )..orderBy([(e) => OrderingTerm.asc(e.startedAt)])).get();
      expect(plays.map((e) => e.songId), [null, 11, 13]);
      expect(plays.first.title, 'Gone');
      expect(plays.last.songPath, '/storage/emulated/0/Download/c.mp3');

      expect(prefs.getString('settings.colorChoice'), 'apricot');
      expect(prefs.getDouble('playback.speed'), 1.25);
      expect(prefs.getStringList('library.excludedFolders'), ['$_music/Voice']);
      expect(prefs.getBool('onboarding.completed'), isNull);
    });

    test('merges, never replaces; restoring twice adds nothing', () async {
      final (db, service) = await _oldPhone();
      addTearDown(db.close);
      final backup = await service.collect();

      // Changes since the backup: a new like, the playlist edited.
      await db.favoritesDao.setLiked(1, liked: true, at: DateTime(2026, 10));
      final mix = (await db.playlistsDao.watchPlaylists().first).single;
      await db.playlistsDao.addSongs(mix.id, [2], at: DateTime(2026, 10));

      final report = await service.restore(backup, settings: false);
      expect((report.likesAdded, report.likesKept), (0, 1));
      expect((report.playsAdded, report.playsKept), (0, 3));
      // The edited playlist stays; the backup's version comes in beside it.
      expect((report.playlistsAdded, report.playlistsKept), (1, 0));
      final names = [
        for (final p in await db.playlistsDao.watchPlaylists().first) p.name,
      ];
      expect(names, containsAll(['Mix', 'Mix (2)']));
      expect(await db.select(db.favorites).get(), hasLength(2));

      final again = await service.restore(backup, settings: false);
      expect(
        (again.likesAdded, again.playlistsAdded, again.playsAdded),
        (0, 0, 0),
      );
      expect(again.playlistsKept, 1);
    });

    test('settings of the wrong type are skipped', () async {
      final db = await _library([]);
      addTearDown(db.close);
      final prefs = await createTestPreferences();
      final backup = Backup.decode(
        jsonEncode({
          'format': 'haraplay-backup',
          'version': 1,
          'settings': {
            'playback.speed': 'fast',
            'settings.themeMode': 'dark',
            'unknown.key': 'x',
          },
        }),
      );
      await BackupService(
        db,
        prefs,
        FakeDocumentFiles(),
      ).restore(backup, settings: true);
      expect(prefs.getDouble('playback.speed'), isNull);
      expect(prefs.getString('settings.themeMode'), 'dark');
      expect(prefs.get('unknown.key'), isNull);
    });
  });

  testWidgets('Settings: back up, then restore with settings', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final db = await _library([(1, '$_music/a.mp3')]);
    await db.favoritesDao.setLiked(1, liked: true, at: DateTime(2026));
    final files = FakeDocumentFiles();
    await pumpHaraApp(
      tester,
      database: db,
      documentFiles: files,
      prefs: {...onboardedPrefs, 'settings.colorChoice': 'periwinkle'},
    );
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
      }
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Back up'), 200);
    await tester.tap(find.text('Back up'));
    await settle();
    expect(files.savedName, startsWith('haraplay-backup-'));
    expect(
      find.textContaining('1 like, 0 playlists and 0 plays'),
      findsOneWidget,
    );

    // Change a setting, then restore the backup: the colour comes back.
    final backup = Backup.decode(files.savedText!);
    final edited = Backup(
      createdAt: backup.createdAt,
      likes: backup.likes,
      playlists: backup.playlists,
      plays: backup.plays,
      settings: {...backup.settings, 'settings.colorChoice': 'apricot'},
    );
    files.toOpen = (
      name: 'b.json',
      path: null,
      bytes: Uint8List.fromList(utf8.encode(edited.encode())),
    );
    await tester.tap(find.text('Restore from a backup'));
    await settle();
    expect(find.text('Restore backup?'), findsOneWidget);
    expect(find.text('Also restore settings'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await settle();
    expect(find.text('Backup restored'), findsOneWidget);
    expect(
      find.textContaining('Likes: 0 added (1 already here)'),
      findsOneWidget,
    );
    expect(find.textContaining('Settings restored'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle();
    expect(
      HaraColors.of(tester.element(find.text('Back up'))).primary,
      HaraPalettes.apricotLight.primary,
    );
  });

  test('restore report wording', () {
    expect(
      describeRestore(
        const RestoreReport(
          likesAdded: 3,
          playlistsAdded: 1,
          playlistsKept: 1,
          playsAdded: 120,
          missingSongs: 2,
        ),
      ),
      'Likes: 3 added\n'
      'Playlists: 1 added (1 already here)\n'
      'Plays: 120 added\n'
      "2 songs from the backup aren't on this phone. Their plays still count "
      "in your stats; likes and playlist entries of them couldn't be added.",
    );
  });
}
