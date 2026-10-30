import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/artwork/song_artwork.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/hara_button.dart';
import '../../../core/widgets/hara_sheet.dart';
import '../domain/queue_song.dart';
import 'player_providers.dart';

Future<void> showQueueSheet(BuildContext context) => showHaraSheet<void>(
  context: context,
  scrollable: false,
  builder: (_) => const QueueSheet(),
);

/// The queue in play order: tap to play, drag the grip to reorder, swipe
/// away to remove. The current song is highlighted and stays put.
class QueueSheet extends ConsumerStatefulWidget {
  const QueueSheet({super.key});

  static const double rowHeight = 64;

  @override
  ConsumerState<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<QueueSheet> {
  ScrollController? _scroll;

  /// Rows swiped away whose removal the player has not confirmed yet; a
  /// dismissed Dismissible must leave the tree on the next frame.
  final _removed = <Key>{};
  List<QueueSong>? _lastQueue;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  /// Keys stay unique when a song is queued twice: "id#occurrence".
  static List<Key> _keysFor(List<QueueSong> queue) {
    final seen = <int, int>{};
    return [
      for (final song in queue)
        ValueKey('${song.id}#${seen[song.id] = (seen[song.id] ?? 0) + 1}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(playbackStatusProvider).value;
    final queue = status?.queue ?? const <QueueSong>[];
    final current = status?.queueIndex ?? 0;
    if (!identical(queue, _lastQueue)) {
      _lastQueue = queue;
      _removed.clear();
    }
    // Open scrolled so the current song is near the top.
    _scroll ??= ScrollController(
      initialScrollOffset:
          (current - 1).clamp(0, 1 << 20) * QueueSheet.rowHeight,
    );
    final keys = _keysFor(queue);
    final player = ref.read(playerProvider);
    final upcoming = status?.upcomingCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          upcoming: upcoming,
          onClear: upcoming == 0 ? null : player.clearUpcoming,
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: _scroll,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: HaraSpacing.xl),
            itemCount: queue.length,
            // The new index is already adjusted for the moved row.
            onReorderItem: player.moveInQueue,
            itemBuilder: (context, index) {
              final key = keys[index];
              if (_removed.contains(key)) {
                return SizedBox.shrink(key: key);
              }
              final row = _QueueRow(
                index: index,
                song: queue[index],
                isCurrent: index == current,
                isPlayed: index < current,
                onTap: () => player.skipTo(index),
              );
              if (index == current) return KeyedSubtree(key: key, child: row);
              return Dismissible(
                key: key,
                direction: DismissDirection.endToStart,
                background: const _RemoveBackground(),
                onDismissed: (_) {
                  setState(() => _removed.add(key));
                  player.removeFromQueue(index);
                },
                child: row,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.upcoming, required this.onClear});

  final int upcoming;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaraSpacing.gutter,
        0,
        HaraSpacing.xs,
        HaraSpacing.sm,
      ),
      child: Row(
        children: [
          Semantics(
            header: true,
            label: upcoming == 1
                ? 'Up next, 1 song'
                : 'Up next, $upcoming songs',
            excludeSemantics: true,
            child: Row(
              children: [
                Text('UP NEXT', style: textTheme.titleLarge),
                const SizedBox(width: HaraSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HaraSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(HaraRadius.pill),
                    border: Border.all(
                      color: colors.border,
                      width: HaraBorder.thin,
                    ),
                  ),
                  child: Text(
                    '$upcoming',
                    style: HaraTextStyles.of(context).monoStrong
                        .copyWith(color: colors.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          HaraButton(
            label: 'Clear',
            variant: HaraButtonVariant.ghost,
            size: HaraButtonSize.small,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.index,
    required this.song,
    required this.isCurrent,
    required this.isPlayed,
    required this.onTap,
  });

  final int index;
  final QueueSong song;
  final bool isCurrent;
  final bool isPlayed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final foreground = isCurrent ? colors.onPrimary : colors.foreground;

    return Semantics(
      button: true,
      selected: isCurrent,
      label:
          '${song.title}, ${song.displayArtist}'
          '${isCurrent ? ', now playing' : ''}',
      hint: isCurrent ? null : 'Swipe left to remove',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isCurrent ? colors.primary : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: isPlayed ? 0.55 : 1,
            child: SizedBox(
              height: QueueSheet.rowHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: HaraSpacing.gutter),
                child: Row(
                  children: [
                    SongArtwork(
                      songId: song.id,
                      albumId: song.albumId,
                      version: song.version,
                      size: 40,
                      borderRadius: HaraRadius.sm,
                    ),
                    const SizedBox(width: HaraSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isCurrent) ...[
                                Icon(
                                  HaraIcons.audioLines,
                                  size: 16,
                                  color: foreground,
                                ),
                                const SizedBox(width: HaraSpacing.xs + 2),
                              ],
                              Expanded(
                                child: Text(
                                  song.title,
                                  style: textTheme.titleSmall!.copyWith(
                                    color: foreground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            song.displayArtist,
                            style: textTheme.bodySmall!.copyWith(
                              color: isCurrent ? colors.onPrimary : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatDuration(song.duration),
                      style: HaraTextStyles.of(context).mono
                          .copyWith(color: isCurrent ? colors.onPrimary : null),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: SizedBox.square(
                        dimension: HaraSizes.minTouchTarget,
                        child: Icon(
                          HaraIcons.gripVertical,
                          size: HaraSizes.iconSmall,
                          color: isCurrent
                              ? colors.onPrimary
                              : colors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    final colors = HaraColors.of(context);
    return ColoredBox(
      color: colors.danger,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: HaraSpacing.xl),
          child: Icon(HaraIcons.trash2, color: colors.onDanger),
        ),
      ),
    );
  }
}
