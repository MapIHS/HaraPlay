import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/widgets/hara_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../library/data/library_sync_service.dart';
import '../../library/data/tag_enrichment_service.dart';
import '../../library/presentation/library_providers.dart';

final _tableCountsProvider = StreamProvider.autoDispose<Map<String, int>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  const tables = {
    'songs': 'songs',
    'tag fallbacks': 'song_tag_fallbacks',
    'favorites': 'favorites',
    'playlists': 'playlists',
    'entries': 'playlist_entries',
    'play events': 'play_events',
  };
  return db
      .customSelect(
        'SELECT ${[for (final MapEntry(:key, :value) in tables.entries) "(SELECT COUNT(*) FROM $value) AS \"$key\""].join(', ')}, '
        '(SELECT COUNT(*) FROM song_tag_fallbacks WHERE failed) AS "failed reads"',
        readsFrom: {
          db.songs,
          db.songTagFallbacks,
          db.favorites,
          db.playlists,
          db.playlistEntries,
          db.playEvents,
        },
      )
      .watchSingle()
      .map(
        (row) => {
          for (final key in [...tables.keys, 'failed reads'])
            key: row.read<int>(key),
        },
      );
});

final _recentEventsProvider = StreamProvider.autoDispose<List<PlayEventRow>>(
  (ref) => ref.watch(appDatabaseProvider).playEventsDao.watchRecent(limit: 10),
);

final _songsProvider =
    StreamProvider.autoDispose<List<(SongRow, SongTagFallbackRow?)>>(
      (ref) => ref.watch(libraryDaoProvider).watchSongsWithFallbacks(),
    );

/// Debug view of the library database: table counts, the last sync, the
/// tag pass, and each song's stored tags next to what its file said.
class LibraryDatabaseDebugScreen extends ConsumerWidget {
  const LibraryDatabaseDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(_tableCountsProvider).value ?? const {};
    final visible = ref.watch(libraryCountsProvider).value;
    final sync = ref.watch(librarySyncControllerProvider);
    final enrichment = ref.watch(tagEnrichmentServiceProvider).progress;
    final songs = ref.watch(_songsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Library database')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
        children: [
          const SectionHeader(title: 'Tables'),
          _Padded(
            Wrap(
              spacing: HaraSpacing.sm,
              runSpacing: HaraSpacing.sm,
              children: [
                for (final MapEntry(:key, :value) in counts.entries)
                  HaraChip(value: '$value', label: key),
                if (visible != null)
                  HaraChip(value: '${visible.songs}', label: 'visible songs'),
              ],
            ),
          ),
          const SectionHeader(title: 'Last sync'),
          _Padded(
            Text(switch (sync) {
              AsyncData(value: null) => 'No sync yet in this session',
              AsyncData(:final value?) => '$value',
              AsyncError(:final error) => 'Failed: $error',
              _ => 'Syncing…',
            }, style: HaraTextStyles.of(context).mono),
          ),
          const SectionHeader(title: 'Tag pass'),
          _Padded(
            ValueListenableBuilder<EnrichmentProgress>(
              valueListenable: enrichment,
              builder: (context, p, _) => Text(
                p.total == 0
                    ? 'Nothing to read'
                    : '${p.done} / ${p.total} files read'
                          '${p.running ? '…' : ' (done)'}',
                style: HaraTextStyles.of(context).mono,
              ),
            ),
          ),
          const SectionHeader(title: 'Recent play events'),
          _Padded(
            Text(
              [
                for (final e
                    in ref.watch(_recentEventsProvider).value ??
                        const <PlayEventRow>[])
                  '${e.title} · ${(e.listenedMs / 1000).toStringAsFixed(1)} s'
                      ' of ${(e.durationMs / 1000).round()} s'
                      '${e.completed ? ' · completed' : ''} · ${e.source.name}',
              ].join('\n').ifEmpty('No plays yet'),
              style: HaraTextStyles.of(context).mono,
            ),
          ),
          SectionHeader(title: 'Songs (${songs.length})'),
          for (final (song, fallback) in songs)
            _SongRowView(song: song, fallback: fallback),
        ],
      ),
    );
  }
}

class _SongRowView extends StatelessWidget {
  const _SongRowView({required this.song, required this.fallback});

  final SongRow song;
  final SongTagFallbackRow? fallback;

  @override
  Widget build(BuildContext context) {
    final mono = HaraTextStyles.of(context).mono;
    final colors = HaraColors.of(context);
    final f = fallback;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HaraSpacing.gutter,
        vertical: HaraSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(song.title, style: Theme.of(context).textTheme.titleSmall),
          Text(
            'stored: ${song.artist ?? '—'} · ${song.album ?? '—'} · '
            'year ${song.year ?? '—'} · ${song.genre ?? '—'} · '
            '#${song.trackNumber ?? '—'} · ${(song.durationMs / 1000).round()} s',
            style: mono,
          ),
          if (song.nameFromFilename)
            Text(
              'artist + title: from filename',
              style: mono.copyWith(color: colors.danger),
            ),
          Text(
            f == null
                ? 'file: not read'
                : f.failed
                ? 'file: read failed'
                : 'file: ${f.artist ?? '—'} · ${f.album ?? '—'} · '
                      'year ${f.year ?? '—'} · ${f.genre ?? '—'} · '
                      '#${f.trackNumber ?? '—'}',
            style: mono.copyWith(color: colors.emphasis),
          ),
        ],
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      HaraSpacing.gutter,
      HaraSpacing.xs,
      HaraSpacing.gutter,
      HaraSpacing.md,
    ),
    child: child,
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
