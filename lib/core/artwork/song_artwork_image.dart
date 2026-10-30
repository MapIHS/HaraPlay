import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'artwork_cache.dart';

/// Thrown into the image stream when a song has no artwork, so that
/// `Image.errorBuilder` shows the placeholder.
class NoArtworkException implements Exception {
  const NoArtworkException();
}

/// An [ImageProvider] for a song's cover art, loaded through [ArtworkCache].
/// Equality ignores the cache, so Flutter's ImageCache keys on the request.
@immutable
class SongArtworkImage extends ImageProvider<SongArtworkImage> {
  const SongArtworkImage(this.cache, this.request);

  final ArtworkCache cache;
  final ArtworkRequest request;

  @override
  Future<SongArtworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    SongArtworkImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _loadCodec(decode),
    scale: 1,
    debugLabel: 'song ${request.songId} @${request.sizePx}px',
  );

  Future<ui.Codec> _loadCodec(ImageDecoderCallback decode) async {
    final bytes = await cache.load(request);
    if (bytes == null) throw const NoArtworkException();
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is SongArtworkImage && other.request == request;

  @override
  int get hashCode => request.hashCode;
}
