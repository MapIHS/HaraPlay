import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/library/data/file_tag_reader.dart';
import 'package:haraplay/features/library/data/library_sync_service.dart';
import 'package:haraplay/features/library/data/tag_enrichment_service.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('enrichment reads candidates in batches and merges the tags', () async {
    await db.libraryDao.applyScan([
      for (var i = 1; i <= 5; i++) mediaSong(i, genre: 'Pop', track: 1),
    ]);
    final reader = FakeFileTagReader({
      for (var i = 1; i <= 4; i++)
        '/storage/emulated/0/Music/song$i.mp3': SongTags(year: 2000 + i),
    });
    final service = TagEnrichmentService(
      db.libraryDao,
      reader: reader,
      batchSize: 2,
    );
    addTearDown(service.dispose);

    await service.run();

    expect(reader.batches.map((b) => b.length), [2, 2, 1]);
    expect(service.progress.value.done, 5);
    expect(service.progress.value.running, isFalse);
    final years = await db.select(db.songs).map((s) => s.year).get();
    expect(years, [2001, 2002, 2003, 2004, null]); // song 5 failed

    // Nothing left to do on the next run.
    reader.batches.clear();
    await service.run();
    expect(reader.batches, isEmpty);
  });

  test('sync mirrors MediaStore and starts the tag pass', () async {
    final source = FakeMediaSource([mediaSong(1, genre: 'Jazz', track: 2)]);
    final reader = FakeFileTagReader({
      '/storage/emulated/0/Music/song1.mp3': const SongTags(year: 2015),
    });
    final enrichment = TagEnrichmentService(db.libraryDao, reader: reader);
    addTearDown(enrichment.dispose);
    final sync = LibrarySyncService(source, db.libraryDao, enrichment);

    final result = await sync.sync();
    expect(result.added, 1);

    // The tag pass runs in the background; wait for it to finish.
    await enrichment.run();
    final song = await db.select(db.songs).getSingle();
    expect(song.year, 2015);
  });

  test('concurrent sync calls share one run', () async {
    final source = FakeMediaSource([mediaSong(1)]);
    final enrichment = TagEnrichmentService(
      db.libraryDao,
      reader: FakeFileTagReader(),
    );
    addTearDown(enrichment.dispose);
    final sync = LibrarySyncService(source, db.libraryDao, enrichment);

    final first = sync.sync();
    final second = sync.sync();
    expect(identical(first, second), isTrue);
    await first;
  });

  test('readFileTags reports unreadable files as failed', () {
    expect(readFileTags('/does/not/exist.mp3').failed, isTrue);
  });
}
