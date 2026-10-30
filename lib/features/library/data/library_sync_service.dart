import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/library_dao.dart';
import '../../../core/platform/media_source.dart';
import '../../../core/platform/media_store_channel.dart';
import 'tag_enrichment_service.dart';

/// Mirrors MediaStore into the database, then starts the background tag
/// pass without waiting for it.
class LibrarySyncService {
  LibrarySyncService(this._source, this._dao, this._enrichment);

  final MediaSource _source;
  final LibraryDao _dao;
  final TagEnrichmentService _enrichment;

  Future<SyncResult>? _running;

  /// Calls made while a sync is running share its result.
  Future<SyncResult> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncResult> _sync() async {
    final scanned = await _source.querySongs();
    final result = await _dao.applyScan(scanned);
    unawaited(_enrichment.run());
    return result;
  }
}

final libraryDaoProvider = Provider<LibraryDao>(
  (ref) => ref.watch(appDatabaseProvider).libraryDao,
);

final tagEnrichmentServiceProvider = Provider<TagEnrichmentService>((ref) {
  final service = TagEnrichmentService(ref.watch(libraryDaoProvider));
  ref.onDispose(service.dispose);
  return service;
});

final librarySyncServiceProvider = Provider<LibrarySyncService>(
  (ref) => LibrarySyncService(
    ref.watch(mediaSourceProvider),
    ref.watch(libraryDaoProvider),
    ref.watch(tagEnrichmentServiceProvider),
  ),
);
