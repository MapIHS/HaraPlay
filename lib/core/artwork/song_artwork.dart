import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/hara_tokens.dart';
import '../widgets/artwork_image.dart';
import 'artwork_cache.dart';
import 'song_artwork_image.dart';

/// [ArtworkImage] showing a song's (or album's) cover art, with the
/// coloured placeholder when there is none.
class SongArtwork extends ConsumerWidget {
  const SongArtwork({
    super.key,
    required this.songId,
    required this.albumId,
    required this.version,
    this.size,
    this.shadow = false,
    this.borderRadius = HaraRadius.md,
    this.borderWidth = HaraBorder.thin,
  });

  final int songId;
  final int? albumId;

  /// The song's date_modified.
  final int version;

  /// Null fills the available width.
  final double? size;
  final bool shadow;
  final double borderRadius;
  final double borderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(artworkCacheProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget image(double logicalSize) => ArtworkImage(
      size: size,
      seed: albumId ?? songId,
      shadow: shadow,
      borderRadius: borderRadius,
      borderWidth: borderWidth,
      image: SongArtworkImage(
        cache,
        ArtworkRequest(
          songId: songId,
          albumId: albumId,
          sizePx: ArtworkCache.bucketFor(logicalSize * dpr),
          version: version,
        ),
      ),
    );

    final fixed = size;
    if (fixed != null) return image(fixed);
    return LayoutBuilder(
      builder: (context, constraints) => image(constraints.maxWidth),
    );
  }
}
