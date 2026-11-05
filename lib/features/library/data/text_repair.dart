import 'package:flutter/services.dart';

import '../../../core/database/daos/library_dao.dart';
import '../../../core/platform/media_store_channel.dart';
import '../../../core/utils/text_normalize.dart';
import 'tag_merge.dart';

/// Repairs mojibake in tag text: Japanese, Chinese or Korean (or UTF-8)
/// bytes read as Latin-1. The decoding tables live on the platform
/// (`TextRepair.kt`); correct text always comes back unchanged.
abstract interface class TextRepairer {
  /// [items] (text, hint) → the repaired texts, in order. The hint (the
  /// file name) breaks ties between plausible readings.
  Future<List<String?>> repairAll(List<(String?, String?)> items);
}

/// Changes nothing: tests, and platforms without the channel.
class NoTextRepair implements TextRepairer {
  const NoTextRepair();

  @override
  Future<List<String?>> repairAll(List<(String?, String?)> items) async => [
    for (final (text, _) in items) text,
  ];
}

/// [TextRepairer] over the media channel.
class PlatformTextRepair implements TextRepairer {
  const PlatformTextRepair(this._channel);

  final MediaStoreChannel _channel;

  @override
  Future<List<String?>> repairAll(List<(String?, String?)> items) async {
    try {
      return await _channel.repairText(items);
    } on PlatformException {
      // Best effort: keep the text as read.
      return [for (final (text, _) in items) text];
    }
  }
}

/// [results] (read from [paths]) with their text fields repaired, in one
/// call for the whole batch. Plain ASCII is never sent: it can't be
/// mojibake.
Future<List<FileTagsResult>> repairFileTags(
  TextRepairer repairer,
  List<String> paths,
  List<FileTagsResult> results,
) async {
  final items = <(String?, String?)>[];
  final slots = <(int, int)>[]; // (result, field)
  for (final (i, result) in results.indexed) {
    if (result.failed) continue;
    final tags = result.tags;
    final fields = [tags.title, tags.artist, tags.album, tags.albumArtist];
    for (final (f, text) in fields.indexed) {
      if (text != null && hasNonAscii(text)) {
        items.add((text, _fileName(paths[i])));
        slots.add((i, f));
      }
    }
  }
  if (items.isEmpty) return results;
  final repaired = await repairer.repairAll(items);
  final fixed = [...results];
  for (final ((i, f), text) in [
    for (var k = 0; k < slots.length; k++) (slots[k], repaired[k]),
  ]) {
    final t = fixed[i].tags;
    fixed[i] = FileTagsResult.read(
      SongTags(
        title: f == 0 ? text : t.title,
        artist: f == 1 ? text : t.artist,
        album: f == 2 ? text : t.album,
        albumArtist: f == 3 ? text : t.albumArtist,
        genre: t.genre,
        trackNumber: t.trackNumber,
        discNumber: t.discNumber,
        year: t.year,
      ),
    );
  }
  return fixed;
}

String _fileName(String path) => path.substring(path.lastIndexOf('/') + 1);
