import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../../../core/database/daos/library_dao.dart';
import '../../../core/tags/id3.dart';
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
///
/// Title, artist, album and album artist come from HaraPlay's own ID3
/// reader when the file has ID3 tags: `audio_metadata_reader` reads UTF-16
/// big-endian text with the bytes swapped and fails on files with only an
/// ID3v1 tag.
FileTagsResult readFileTags(String path) {
  Id3Text? id3;
  try {
    id3 = readId3Text(path);
  } on Object {
    // Unreadable: the reader below fails the same way.
  }
  try {
    final metadata = readMetadata(File(path));
    return FileTagsResult.read(
      SongTags(
        title: _text(id3?.title) ?? _text(metadata.title),
        artist: _text(id3?.artist) ?? _text(metadata.artist),
        album: _text(id3?.album) ?? _text(metadata.album),
        albumArtist: _text(id3?.albumArtist) ?? _text(metadata.albumArtist),
        genre: metadata.genres.map(_text).nonNulls.firstOrNull,
        trackNumber: _positive(metadata.trackNumber),
        discNumber: _positive(metadata.discNumber),
        year: _positive(metadata.year?.year),
      ),
    );
  } on Object {
    // Unsupported format, truncated file or no read access. ID3 text alone
    // is still worth keeping (e.g. an MP3 with only an ID3v1 tag).
    if (id3 != null && !id3.isEmpty) {
      return FileTagsResult.read(
        SongTags(
          title: _text(id3.title),
          artist: _text(id3.artist),
          album: _text(id3.album),
          albumArtist: _text(id3.albumArtist),
        ),
      );
    }
    return const FileTagsResult.failed();
  }
}

String? _text(String? value) {
  final trimmed = value?.replaceAll('\u0000', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int? _positive(int? value) => value != null && value > 0 ? value : null;
