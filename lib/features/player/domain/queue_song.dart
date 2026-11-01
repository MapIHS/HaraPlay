import '../../../core/database/app_database.dart';
import '../../library/domain/library_models.dart';

/// A song as the player needs it: what to play, and what to show and record.
class QueueSong {
  const QueueSong({
    required this.id,
    required this.title,
    required this.path,
    required this.duration,
    required this.version,
    this.artist,
    this.album,
    this.albumId,
    this.contentUri,
    this.trackNumber,
    this.discNumber,
    this.taggedAlbum,
  });

  /// A file opened from another app ("Open with") that is not in the
  /// library. It gets a negative [id], plays from [uri], and is never
  /// recorded, saved with the queue, liked or added to playlists.
  factory QueueSong.external({
    required int id,
    required Uri uri,
    required String title,
    String? artist,
    String? album,
    Duration duration = Duration.zero,
  }) {
    assert(id < 0, 'external songs use negative IDs');
    return QueueSong(
      id: id,
      title: title,
      artist: artist,
      album: album,
      path: '',
      duration: duration,
      version: 0,
      contentUri: uri,
    );
  }

  factory QueueSong.fromRow(SongRow row) => QueueSong(
    id: row.id,
    title: row.title,
    artist: row.artist,
    album: row.album,
    albumId: row.albumId,
    path: row.path,
    duration: Duration(milliseconds: row.durationMs),
    version: row.dateModified,
    trackNumber: row.trackNumber,
    discNumber: row.discNumber,
    taggedAlbum: realAlbumTag(row.album, folderName: row.folderName),
  );

  final int id;
  final String title;
  final String? artist;
  final String? album;
  final int? albumId;
  final String path;
  final Duration duration;

  /// date_modified, for artwork caching.
  final int version;

  /// Set for [QueueSong.external] songs only.
  final Uri? contentUri;

  final int? trackNumber;
  final int? discNumber;

  /// The album tag when it is a real one (see [realAlbumTag]); crossfade
  /// keeps consecutive tracks of a real album gapless.
  final String? taggedAlbum;

  /// Opened from another app and not in the library.
  bool get isExternal => id < 0;

  /// MediaStore content URI (playback never needs file-path access), or
  /// the URI another app handed over.
  Uri get uri =>
      contentUri ?? Uri.parse('content://media/external/audio/media/$id');

  String get displayArtist => artist ?? unknownArtist;
  String get displayAlbum => album ?? unknownAlbum;

  @override
  bool operator ==(Object other) => other is QueueSong && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// What the UI shows about playback.
class PlaybackStatus {
  const PlaybackStatus({
    required this.song,
    required this.playing,
    required this.buffering,
    required this.duration,
    this.shuffle = false,
    this.repeat = RepeatSetting.off,
    this.source = PlaySource.songs,
    this.sourceLabel,
    this.queue = const [],
    this.queueIndex = 0,
    this.speed = 1,
  });

  static const idle = PlaybackStatus(
    song: null,
    playing: false,
    buffering: false,
    duration: Duration.zero,
  );

  final QueueSong? song;
  final bool playing;
  final bool buffering;
  final Duration duration;
  final bool shuffle;
  final RepeatSetting repeat;

  /// Where the queue came from, e.g. [PlaySource.album] and "Night Drive".
  final PlaySource source;
  final String? sourceLabel;

  /// The whole queue in play order; [queueIndex] is the current song.
  final List<QueueSong> queue;
  final int queueIndex;

  /// Playback speed; 1 is normal (A7d).
  final double speed;

  int get queueLength => queue.length;

  /// Songs after the current one.
  int get upcomingCount => (queue.length - queueIndex - 1).clamp(0, 1 << 30);

  PlaybackStatus copyWith({
    bool? playing,
    bool? shuffle,
    RepeatSetting? repeat,
    double? speed,
  }) => PlaybackStatus(
    song: song,
    playing: playing ?? this.playing,
    buffering: buffering,
    duration: duration,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    source: source,
    sourceLabel: sourceLabel,
    queue: queue,
    queueIndex: queueIndex,
    speed: speed ?? this.speed,
  );
}

/// The index [step] places from [current] in a queue of [length], or null
/// at either end unless [wrap] (repeat all) is set.
int? neighbourIndex({
  required int? current,
  required int length,
  required int step,
  required bool wrap,
}) {
  if (current == null || length == 0) return null;
  final target = current + step;
  if (target >= 0 && target < length) return target;
  return wrap ? target % length : null;
}

extension PlaybackNeighbours on PlaybackStatus {
  /// The queue index [step] places from the current song, as the skip
  /// buttons move: wrapping only under repeat all.
  int? neighbour(int step) => neighbourIndex(
    current: song == null ? null : queueIndex,
    length: queue.length,
    step: step,
    wrap: repeat == RepeatSetting.all,
  );
}

/// [album] if it is a real album tag: not missing, and not just the
/// folder's name (MediaStore names untagged files' album after their
/// folder). Compared case-insensitively.
String? realAlbumTag(String? album, {required String folderName}) {
  final name = album?.trim();
  if (name == null || name.isEmpty) return null;
  if (name.toLowerCase() == folderName.trim().toLowerCase()) return null;
  return name;
}
