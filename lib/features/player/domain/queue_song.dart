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
  });

  factory QueueSong.fromRow(SongRow row) => QueueSong(
    id: row.id,
    title: row.title,
    artist: row.artist,
    album: row.album,
    albumId: row.albumId,
    path: row.path,
    duration: Duration(milliseconds: row.durationMs),
    version: row.dateModified,
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

  /// MediaStore content URI; playback never needs file-path access.
  Uri get uri => Uri.parse('content://media/external/audio/media/$id');

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
    this.queueLength = 0,
    this.queueIndex = 0,
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
  final int queueLength;
  final int queueIndex;

  PlaybackStatus copyWith({
    bool? playing,
    bool? shuffle,
    RepeatSetting? repeat,
  }) => PlaybackStatus(
    song: song,
    playing: playing ?? this.playing,
    buffering: buffering,
    duration: duration,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    source: source,
    sourceLabel: sourceLabel,
    queueLength: queueLength,
    queueIndex: queueIndex,
  );
}
