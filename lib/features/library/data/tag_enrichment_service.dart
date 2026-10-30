import 'package:flutter/foundation.dart';

import '../../../core/database/daos/library_dao.dart';
import 'file_tag_reader.dart';

/// Progress of the background tag pass.
@immutable
class EnrichmentProgress {
  const EnrichmentProgress({
    required this.done,
    required this.total,
    required this.running,
  });

  static const idle = EnrichmentProgress(done: 0, total: 0, running: false);

  final int done;
  final int total;
  final bool running;
}

/// Fills in tags MediaStore missed by reading the files themselves
/// (docs/PLAN.md §6.1). Runs in the background after each sync; results
/// reach the UI through the database streams.
class TagEnrichmentService {
  TagEnrichmentService(
    this._dao, {
    this._reader = const FileTagReader(),
    this.batchSize = 25,
    this._clock = DateTime.now,
  });

  final LibraryDao _dao;
  final FileTagReader _reader;
  final DateTime Function() _clock;
  final int batchSize;

  final progress = ValueNotifier(EnrichmentProgress.idle);
  Future<void>? _running;
  bool _disposed = false;

  /// Reads all current candidates. Calls while a pass is running join it.
  Future<void> run() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  Future<void> _run() async {
    final watch = Stopwatch()..start();
    final candidates = await _dao.enrichmentCandidates();
    var done = 0;
    _report(done, candidates.length, running: candidates.isNotEmpty);
    for (var start = 0; start < candidates.length; start += batchSize) {
      if (_disposed) return;
      final batch = candidates.skip(start).take(batchSize).toList();
      final results = await _reader.readAll([for (final s in batch) s.path]);
      if (_disposed) return;
      await _dao.saveFileTags([
        for (var i = 0; i < batch.length; i++) (batch[i], results[i]),
      ], readAt: _clock());
      done += batch.length;
      _report(done, candidates.length, running: done < candidates.length);
    }
    if (!kReleaseMode && candidates.isNotEmpty) {
      debugPrint(
        'HaraPlay tag pass: ${candidates.length} files in '
        '${watch.elapsedMilliseconds} ms',
      );
    }
  }

  void _report(int done, int total, {required bool running}) {
    if (_disposed) return;
    progress.value = EnrichmentProgress(
      done: done,
      total: total,
      running: running,
    );
  }

  void dispose() {
    _disposed = true;
    progress.dispose();
  }
}
