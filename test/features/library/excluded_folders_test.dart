import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/library/data/auto_rescan.dart';
import 'package:haraplay/features/library/data/library_sync_service.dart';
import 'package:haraplay/features/library/data/tag_enrichment_service.dart';
import 'package:haraplay/features/library/domain/excluded_folders.dart';
import 'package:haraplay/features/library/domain/library_sort.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_database.dart';

const _root = '/storage/emulated/0';

void main() {
  group('folder helpers', () {
    test('display names', () {
      expect(
        displayFolder('$_root/Music/WhatsApp Audio'),
        'Music/WhatsApp Audio',
      );
      expect(displayFolder(_root), 'Phone storage');
      expect(displayFolder('/storage/1A2B-3C4D/Music'), 'SD card · Music');
      expect(displayFolder('/data/x'), '/data/x');
    });

    test('choices include parent folders, with songs counted upwards', () {
      final choices = folderChoices({
        '$_root/Music': 3,
        '$_root/Music/Rock': 2,
        '$_root/Download': 1,
      }, const []);
      expect(choices, [
        (path: '$_root/Download', songCount: 1),
        (path: '$_root/Music', songCount: 5),
        (path: '$_root/Music/Rock', songCount: 2),
      ]);
    });

    test('excluded folders and their subfolders are not offered', () {
      final choices = folderChoices(
        {
          '$_root/Music/Rock': 2,
          '$_root/Music/Rock/Live': 1,
          '$_root/Music/Rockabilly': 4,
        },
        const ['$_root/Music/Rock'],
      );
      expect(choices.map((c) => c.path), [
        '$_root/Music',
        '$_root/Music/Rockabilly',
      ]);
    });

    test('adding a parent replaces its excluded subfolders', () {
      expect(
        addExcludedFolder([
          '$_root/Music/Rock/Live',
          '$_root/Ringtones',
        ], '$_root/Music/Rock'),
        ['$_root/Music/Rock', '$_root/Ringtones'],
      );
    });
  });

  group('the database', () {
    late AppDatabase db;
    setUp(() async {
      db = createTestDatabase();
      await db.libraryDao.applyScan([
        mediaSong(1, path: '$_root/Music/a.mp3'),
        mediaSong(2, path: '$_root/Music/Voice/b.mp3'),
        mediaSong(3, path: '$_root/Music/Voice/Old/c.mp3'),
        mediaSong(4, path: '$_root/Music/Voices/d.mp3'),
        mediaSong(5, path: '$_root/Music/100%_x/e.mp3'),
      ]);
    });
    tearDown(() => db.close());

    Future<List<int>> visible() async => [
      for (final s
          in await db.browseDao
              .watchSongs(
                const LibrarySort(SongSortField.title),
                minDurationMs: 0,
              )
              .first)
        s.id,
    ]..sort();

    test(
      'hides a folder and its subfolders, but not look-alike names',
      () async {
        await db.libraryDao.applyExclusions(['$_root/Music/Voice']);
        expect(await visible(), [1, 4, 5]);
        expect((await db.libraryDao.counts(minDurationMs: 0)).songs, 3);
        expect(
          await db.searchDao.searchSongs('Song', minDurationMs: 0),
          hasLength(3),
        );

        // Wildcard characters in a folder name match only themselves.
        await db.libraryDao.applyExclusions(['$_root/Music/100%_x']);
        expect(await visible(), [1, 2, 3, 4]);

        await db.libraryDao.applyExclusions(const []);
        expect(await visible(), [1, 2, 3, 4, 5]);
      },
    );

    test('liked songs stay in Liked songs', () async {
      await db.favoritesDao.setLiked(2, liked: true, at: DateTime(2026));
      await db.libraryDao.applyExclusions(['$_root/Music/Voice']);
      final liked = await db.favoritesDao.watchLikedSongs().first;
      expect(liked.map((s) => s.id), [2]);
    });

    test('a rescan keeps excluded songs hidden', () async {
      final source = FakeMediaSource([
        mediaSong(1, path: '$_root/Music/a.mp3'),
        mediaSong(2, path: '$_root/Music/Voice/b.mp3', modifiedSec: 1800000000),
        mediaSong(6, path: '$_root/Music/Voice/new.mp3'),
      ]);
      final enrichment = TagEnrichmentService(
        db.libraryDao,
        reader: FakeFileTagReader(),
      );
      addTearDown(enrichment.dispose);
      final sync = LibrarySyncService(
        source,
        db.libraryDao,
        enrichment,
        null,
        () => ['$_root/Music/Voice'],
      );
      await sync.sync();
      // Let the background tag pass finish before the database closes.
      await enrichment.run();
      expect(await visible(), [1]);
    });
  });

  group('auto-rescan', () {
    test(
      'rescans after a change, once more if one arrives meanwhile',
      () async {
        final changes = StreamController<void>.broadcast();
        addTearDown(changes.close);
        final gate = <Completer<void>>[];
        var enabled = true;
        final rescan = AutoRescan(
          changes: changes.stream,
          sync: () {
            final c = Completer<void>();
            gate.add(c);
            return c.future;
          },
          enabled: () => enabled,
        )..start();
        addTearDown(rescan.dispose);

        changes.add(null);
        await pumpEventQueue();
        expect(gate, hasLength(1));

        // Two changes during the running scan: one follow-up scan.
        changes
          ..add(null)
          ..add(null);
        await pumpEventQueue();
        expect(gate, hasLength(1));
        gate[0].completeError(StateError('scan failed'));
        await pumpEventQueue();
        expect(gate, hasLength(2), reason: 'errors do not stop it');
        gate[1].complete();
        await pumpEventQueue();
        expect(gate, hasLength(2));

        // Before onboarding has finished, changes are ignored.
        enabled = false;
        changes.add(null);
        await pumpEventQueue();
        expect(gate, hasLength(2));
      },
    );
  });
}
