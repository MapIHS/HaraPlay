import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../../../core/database/daos/library_dao.dart';
import 'tag_merge.dart';

/// Reads tags straight from audio files with `audio_metadata_reader`.
/// Each batch runs in a short-lived isolate so parsing never blocks the UI.
class FileTagReader {
  const FileTagReader();

  Future<List<FileTagsResult>> readAll(List<String> paths) =>
      Isolate.run(() => paths.map(readFileTags).toList());
}

/// Reads one file. Never throws; unreadable files become
/// [FileTagsResult.failed].
FileTagsResult readFileTags(String path) {
  try {
    final metadata = readMetadata(File(path));
    return FileTagsResult.read(
      SongTags(
        title: _text(metadata.title),
        artist: _text(metadata.artist),
        album: _text(metadata.album),
        albumArtist: _text(metadata.albumArtist),
        genre: metadata.genres.map(_text).nonNulls.firstOrNull,
        trackNumber: _positive(metadata.trackNumber),
        discNumber: _positive(metadata.discNumber),
        year: _positive(metadata.year?.year),
      ),
    );
  } on Object {
    // Unsupported format, truncated file or no read access.
    return const FileTagsResult.failed();
  }
}

String? _text(String? value) {
  final trimmed = value?.replaceAll('\u0000', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int? _positive(int? value) => value != null && value > 0 ? value : null;
