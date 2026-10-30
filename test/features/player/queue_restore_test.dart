import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/database/daos/queue_state_dao.dart';
import 'package:haraplay/features/player/domain/queue_restore.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = createTestDatabase();
    await db.libraryDao.applyScan([
      for (var i = 1; i <= 5; i++) mediaSong(i, path: '/m/$i.mp3'),
    ]);
  });
  tearDown(() => db.close());

  SavedQueue saved(
    List<int> ids, {
    int index = 0,
    int positionMs = 0,
    List<int>? original,
  }) => SavedQueue(
    songIds: ids,
    originalSongIds: original,
    currentIndex: index,
    position: Duration(milliseconds: positionMs),
    shuffle: original != null,
    repeat: RepeatSetting.all,
    source: PlaySource.album,
    sourceLabel: 'Night Drive',
  );

  test('saves and loads the queue row', () async {
    final dao = db.queueStateDao;
    await dao.save(
      saved([3, 1, 2], index: 1, positionMs: 4200, original: [1, 2, 3]),
      at: DateTime.utc(2026),
    );
    await dao.savePosition(
      2,
      const Duration(seconds: 9),
      at: DateTime.utc(2026),
    );

    final loaded = (await dao.load())!;
    expect(loaded.songIds, [3, 1, 2]);
    expect(loaded.originalSongIds, [1, 2, 3]);
    expect(loaded.currentIndex, 2);
    expect(loaded.position, const Duration(seconds: 9));
    expect(loaded.shuffle, isTrue);
    expect(loaded.repeat, RepeatSetting.all);
    expect(loaded.source, PlaySource.album);
    expect(loaded.sourceLabel, 'Night Drive');
  });

  test('restores the saved song and position', () async {
    final queue = saved([1, 2, 3], index: 1, positionMs: 30000);
    final plan = planRestore(
      queue,
      await db.queueStateDao.songsByIds([1, 2, 3]),
    )!;
    expect(plan.songs.map((s) => s.id), [1, 2, 3]);
    expect(plan.index, 1);
    expect(plan.position, const Duration(seconds: 30));
    expect(plan.order, isNull);
  });

  test('skips deleted songs and keeps the current one', () async {
    final queue = saved([9, 1, 8, 2, 3], index: 3, positionMs: 5000);
    final plan = planRestore(
      queue,
      await db.queueStateDao.songsByIds([9, 1, 8, 2, 3]),
    )!;
    expect(plan.songs.map((s) => s.id), [1, 2, 3]);
    expect(plan.index, 1); // song 2
    expect(plan.position, const Duration(seconds: 5));
  });

  test('a deleted current song resumes at the start of the next one', () async {
    final queue = saved([1, 9, 2], index: 1, positionMs: 5000);
    final plan = planRestore(
      queue,
      await db.queueStateDao.songsByIds([1, 9, 2]),
    )!;
    expect(plan.songs[plan.index].id, 2);
    expect(plan.position, Duration.zero);
  });

  test('restores the shuffle permutation', () async {
    final queue = saved([3, 1, 2], index: 0, original: [1, 2, 3]);
    final plan = planRestore(
      queue,
      await db.queueStateDao.songsByIds([1, 2, 3]),
    )!;
    expect(plan.order, [2, 0, 1]);
    expect(plan.original.map((s) => s.id), [1, 2, 3]);
  });

  test('nothing left to restore', () async {
    final plan = planRestore(
      saved([8, 9]),
      await db.queueStateDao.songsByIds([8, 9]),
    );
    expect(plan, isNull);
  });
}
