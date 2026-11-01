import 'dart:convert';

/// A song as a backup remembers it: enough to find it again (path, then
/// file name + size) and to keep stats readable when it is gone.
class BackupSong {
  const BackupSong({
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.durationMs = 0,
    this.sizeBytes = 0,
  });

  factory BackupSong.fromJson(Map<String, Object?> json) => BackupSong(
    path: json['path']! as String,
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String?,
    album: json['album'] as String?,
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
  );

  final String path;
  final String title;
  final String? artist;
  final String? album;
  final int durationMs;
  final int sizeBytes;

  Map<String, Object?> toJson() => {
    'path': path,
    'title': title,
    if (artist != null) 'artist': artist,
    if (album != null) 'album': album,
    'durationMs': durationMs,
    'sizeBytes': sizeBytes,
  };
}

typedef BackupLike = ({BackupSong song, int addedAt});

typedef BackupPlaylistEntry = ({BackupSong song, int addedAt});

typedef BackupPlaylist = ({
  String name,
  int createdAt,
  int updatedAt,
  List<BackupPlaylistEntry> entries,
});

/// One play event, as recorded (see `PlayEvents`).
typedef BackupPlay = ({
  BackupSong song,
  int startedAt,
  int listenedMs,
  int durationMs,
  bool completed,
  String source,
});

/// Everything a backup file holds. Times are milliseconds since the epoch.
class Backup {
  const Backup({
    required this.createdAt,
    required this.likes,
    required this.playlists,
    required this.plays,
    required this.settings,
  });

  static const format = 'haraplay-backup';
  static const version = 1;

  final DateTime createdAt;
  final List<BackupLike> likes;
  final List<BackupPlaylist> playlists;
  final List<BackupPlay> plays;

  /// Preference values by key (strings, numbers, booleans, string lists).
  final Map<String, Object> settings;

  String encode() => const JsonEncoder.withIndent(' ').convert({
    'format': format,
    'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'likes': [
      for (final like in likes)
        {'song': like.song.toJson(), 'addedAt': like.addedAt},
    ],
    'playlists': [
      for (final p in playlists)
        {
          'name': p.name,
          'createdAt': p.createdAt,
          'updatedAt': p.updatedAt,
          'entries': [
            for (final e in p.entries)
              {'song': e.song.toJson(), 'addedAt': e.addedAt},
          ],
        },
    ],
    'plays': [
      for (final p in plays)
        {
          'song': p.song.toJson(),
          'startedAt': p.startedAt,
          'listenedMs': p.listenedMs,
          'durationMs': p.durationMs,
          'completed': p.completed,
          'source': p.source,
        },
    ],
    'settings': settings,
  });

  /// Reads a backup file; throws [FormatException] for anything else
  /// (another app's JSON, a newer backup format, a damaged file).
  static Backup decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Not a HaraPlay backup');
    }
    if (json is! Map<String, Object?> || json['format'] != format) {
      throw const FormatException('Not a HaraPlay backup');
    }
    final Map<String, Object?> root = json;
    final version = root['version'];
    if (version is! int || version > Backup.version) {
      throw const FormatException('Made by a newer HaraPlay');
    }
    try {
      List<Map<String, Object?>> list(String key) => [
        for (final item in (root[key] as List<Object?>? ?? const []))
          item! as Map<String, Object?>,
      ];
      BackupSong song(Map<String, Object?> item) =>
          BackupSong.fromJson(item['song']! as Map<String, Object?>);
      int number(Map<String, Object?> item, String key) =>
          (item[key] as num?)?.toInt() ?? 0;
      return Backup(
        createdAt:
            DateTime.tryParse(root['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        likes: [
          for (final item in list('likes'))
            (song: song(item), addedAt: number(item, 'addedAt')),
        ],
        playlists: [
          for (final item in list('playlists'))
            (
              name: item['name']! as String,
              createdAt: number(item, 'createdAt'),
              updatedAt: number(item, 'updatedAt'),
              entries: [
                for (final e in (item['entries'] as List<Object?>? ?? const []))
                  (
                    song: song(e! as Map<String, Object?>),
                    addedAt: number(e as Map<String, Object?>, 'addedAt'),
                  ),
              ],
            ),
        ],
        plays: [
          for (final item in list('plays'))
            (
              song: song(item),
              startedAt: number(item, 'startedAt'),
              listenedMs: number(item, 'listenedMs'),
              durationMs: number(item, 'durationMs'),
              completed: item['completed'] == true,
              source: item['source'] as String? ?? 'songs',
            ),
        ],
        settings: {
          for (final MapEntry(:key, :value)
              in (root['settings'] as Map<String, Object?>? ?? const {})
                  .entries)
            key: ?_settingValue(value),
        },
      );
    } on TypeError {
      throw const FormatException('Damaged backup');
    }
  }

  static Object? _settingValue(Object? value) => switch (value) {
    final String s => s,
    final bool b => b,
    final num n => n,
    final List<Object?> l when l.every((e) => e is String) => l.cast<String>(),
    _ => null,
  };
}

/// What a restore did, for the message afterwards.
class RestoreReport {
  const RestoreReport({
    this.likesAdded = 0,
    this.likesKept = 0,
    this.playlistsAdded = 0,
    this.playlistsKept = 0,
    this.playsAdded = 0,
    this.playsKept = 0,
    this.missingSongs = 0,
    this.settingsRestored = false,
  });

  /// New likes; [likesKept] were already liked.
  final int likesAdded;
  final int likesKept;

  /// New playlists; [playlistsKept] already existed with the same songs.
  final int playlistsAdded;
  final int playlistsKept;

  /// New plays; [playsKept] were already in the history.
  final int playsAdded;
  final int playsKept;

  /// Different songs in the backup that aren't on this phone. Their plays
  /// still count in the stats; likes and playlist entries of them can't
  /// be restored.
  final int missingSongs;

  final bool settingsRestored;
}
