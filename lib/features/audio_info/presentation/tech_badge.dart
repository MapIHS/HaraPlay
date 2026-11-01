import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/theme/hara_typography.dart';
import '../../player/domain/queue_song.dart';
import '../data/audio_info_repository.dart';
import '../domain/audio_info.dart';

/// The audio info key for [song].
AudioInfoKey audioInfoKey(QueueSong song) =>
    (id: song.id, path: song.path, version: song.version);

/// "FLAC · 24-bit / 96 kHz" in a small bordered tag (Now Playing). Its
/// space is kept while the header is read (and for files we can't read),
/// so the layout doesn't jump from song to song.
class TechBadge extends ConsumerWidget {
  const TechBadge({super.key, required this.song});

  final QueueSong song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(audioInfoProvider(audioInfoKey(song))).value;
    final text = info == null ? null : techBadge(info);
    final lossless = info?.lossless ?? false;
    final colors = HaraColors.of(context);
    return Visibility(
      visible: text != null,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Semantics(
        label: text == null ? null : 'Audio format: $text',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HaraSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: lossless ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(HaraRadius.sm),
            border: Border.all(color: colors.border, width: HaraBorder.thin),
          ),
          child: Text(
            text ?? 'MP3',
            style: HaraTextStyles.of(context).mono.copyWith(
              color: lossless ? colors.onPrimary : colors.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
