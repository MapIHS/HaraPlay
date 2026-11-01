import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/artwork/artwork_cache.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/core/platform/media_store_channel.dart';
import 'package:haraplay/core/storage/preferences.dart';
import 'package:haraplay/features/library/data/library_sync_service.dart';
import 'package:haraplay/features/library/data/tag_enrichment_service.dart';
import 'package:haraplay/features/library/presentation/library_providers.dart';
import 'package:haraplay/features/player/presentation/player_providers.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  test('every sync lets the player drop queued songs that are gone', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final source = FakeMediaSource([mediaSong(1), mediaSong(2)]);
    final player = FakePlayer();
    final container = ProviderContainer(
      overrides: [
        // Each sync reads the excluded folders from the settings.
        sharedPreferencesProvider.overrideWithValue(
          await createTestPreferences(),
        ),
        appDatabaseProvider.overrideWithValue(db),
        mediaSourceProvider.overrideWithValue(source),
        playerProvider.overrideWithValue(player),
        artworkCacheProvider.overrideWithValue(FakeArtworkCache()),
        tagEnrichmentServiceProvider.overrideWith((ref) {
          final service = TagEnrichmentService(
            ref.watch(libraryDaoProvider),
            reader: FakeFileTagReader(),
          );
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
    );
    addTearDown(container.dispose);
    final sync = container.read(librarySyncControllerProvider.notifier);

    await sync.sync();
    await Future<void>.delayed(Duration.zero);
    expect(player.dropMissingCalls, 1);

    source.songs = [mediaSong(1)];
    await sync.sync();
    await Future<void>.delayed(Duration.zero);
    expect(player.dropMissingCalls, 2);
  });
}
