import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/platform/document_files.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/text_decode.dart';
import '../../library/domain/song_matcher.dart';
import '../../playlists/domain/m3u.dart';
import '../domain/backup.dart';

/// The settings a backup carries, with the type each is stored as.
/// Device-specific state (onboarding, the queue, the session's lyrics
/// toggle) stays out.
const backupSettingTypes = <String, Type>{
  'settings.themeMode': String,
  'settings.colorChoice': String,
  'settings.minSongLengthSeconds': int,
  'library.excludedFolders': List<String>,
  'library.sort.songs': String,
  'library.sort.albums': String,
  'library.sort.artists': String,
  'library.sort.folders': String,
  'library.sort.genres': String,
  'audio.equalizer': String,
  'audio.replayGain': String,
  'playback.speed': double,
  'playback.crossfadeSeconds': int,
  'playback.crossfadeOnSkip': bool,
};

/// Makes and restores backup files: likes, playlists, the full play
/// history and settings. Restoring merges; it never removes or replaces
/// anything already here.
class BackupService {
  BackupService(
    this._db,
    this._prefs,
    this._files, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SharedPreferencesWithCache _prefs;
  final DocumentFiles _files;
  final DateTime Function() _clock;

  /// Types a picker may label a backup with.
  static const openTypes = [
    'application/json',
    'text/plain',
    'application/octet-stream',
  ];

  // Making a backup ------------------------------------------------------

  Future<Backup> collect() async {
    BackupSong ofSong(SongRow s) => BackupSong(
      path: s.path,
      title: s.title,
      artist: s.artist,
      album: s.album,
      durationMs: s.durationMs,
      sizeBytes: s.sizeBytes,
    );

    final likeRows = await (_db.select(_db.favorites).join([
      innerJoin(_db.songs, _db.songs.id.equalsExp(_db.favorites.songId)),
    ])..orderBy([OrderingTerm.asc(_db.favorites.addedAt)])).get();

    final playlists = <BackupPlaylist>[];
    final playlistRows = await (_db.select(
      _db.playlists,
    )..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();
    for (final playlist in playlistRows) {
      final entries =
          await (_db.select(_db.playlistEntries).join([
                  innerJoin(
                    _db.songs,
                    _db.songs.id.equalsExp(_db.playlistEntries.songId),
                  ),
                ])
                ..where(_db.playlistEntries.playlistId.equals(playlist.id))
                ..orderBy([
                  OrderingTerm.asc(_db.playlistEntries.position),
                  OrderingTerm.asc(_db.playlistEntries.id),
                ]))
              .get();
      playlists.add((
        name: playlist.name,
        createdAt: playlist.createdAt,
        updatedAt: playlist.updatedAt,
        entries: [
          for (final row in entries)
            (
              song: ofSong(row.readTable(_db.songs)),
              addedAt: row.readTable(_db.playlistEntries).addedAt,
            ),
        ],
      ));
    }

    // Every play, also of songs that are gone (they still count in stats).
    final playRows = await (_db.select(_db.playEvents).join([
      leftOuterJoin(_db.songs, _db.songs.id.equalsExp(_db.playEvents.songId)),
    ])..orderBy([OrderingTerm.asc(_db.playEvents.startedAt)])).get();

    return Backup(
      createdAt: _clock(),
      likes: [
        for (final row in likeRows)
          (
            song: ofSong(row.readTable(_db.songs)),
            addedAt: row.readTable(_db.favorites).addedAt,
          ),
      ],
      playlists: playlists,
      plays: [
        for (final row in playRows)
          if (row.readTable(_db.playEvents) case final e)
            (
              song: BackupSong(
                path: e.songPath,
                title: e.title,
                artist: e.artist,
                album: e.album,
                durationMs: e.durationMs,
                sizeBytes: row.readTableOrNull(_db.songs)?.sizeBytes ?? 0,
              ),
              startedAt: e.startedAt,
              listenedMs: e.listenedMs,
              durationMs: e.durationMs,
              completed: e.completed,
              source: e.source.name,
            ),
      ],
      settings: {
        for (final key in backupSettingTypes.keys)
          if (_prefs.get(key) case final Object value) key: value,
      },
    );
  }

  /// Lets the user save a backup. Returns the file name and the backup, or
  /// null if the user cancelled.
  Future<(String, Backup)?> export() async {
    final backup = await collect();
    final now = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    final saved = await _files.save(
      fileName:
          'haraplay-backup-${now.year}-${two(now.month)}-${two(now.day)}.json',
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(backup.encode())),
    );
    return saved == null ? null : (saved, backup);
  }

  // Restoring ------------------------------------------------------------

  /// Lets the user pick a backup file. Null if cancelled; throws
  /// [FormatException] if the file isn't a HaraPlay backup.
  Future<Backup?> pick() async {
    final file = await _files.open(mimeTypes: openTypes);
    if (file == null) return null;
    return Backup.decode(decodeTextFile(file.bytes));
  }

  /// Merges [backup] into the library: adds likes, playlists and plays that
  /// aren't here yet; with [settings], also takes the backup's settings
  /// (call the app's settings reload afterwards).
  Future<RestoreReport> restore(Backup backup, {required bool settings}) async {
    final report = await _db.transaction(() => _restoreData(backup));
    if (!settings) return report;
    await _restoreSettings(backup.settings);
    return RestoreReport(
      likesAdded: report.likesAdded,
      likesKept: report.likesKept,
      playlistsAdded: report.playlistsAdded,
      playlistsKept: report.playlistsKept,
      playsAdded: report.playsAdded,
      playsKept: report.playsKept,
      missingSongs: report.missingSongs,
      settingsRestored: true,
    );
  }

  Future<RestoreReport> _restoreData(Backup backup) async {
    final songs = await _db.select(_db.songs).get();
    final matcher = SongMatcher([
      for (final s in songs) (id: s.id, path: s.path, sizeBytes: s.sizeBytes),
    ]);
    final missing = <String>{};
    MatchableSong? match(BackupSong song) {
      final found = matcher.find(song.path, sizeBytes: song.sizeBytes);
      if (found == null) missing.add(song.path);
      return found;
    }

    // Likes: add the ones not liked yet.
    final liked = {
      for (final f in await _db.select(_db.favorites).get()) f.songId,
    };
    var likesAdded = 0;
    var likesKept = 0;
    for (final like in backup.likes) {
      final song = match(like.song);
      if (song == null) continue;
      if (!liked.add(song.id)) {
        likesKept++;
        continue;
      }
      await _db
          .into(_db.favorites)
          .insert(
            FavoritesCompanion.insert(
              songId: Value(song.id),
              songPath: song.path,
              addedAt: like.addedAt,
            ),
          );
      likesAdded++;
    }

    // Playlists: one already here with the same name and songs is kept;
    // otherwise the backup's comes in as a new playlist ("Mix (2)").
    final existing = <String, List<List<int>>>{};
    for (final p in await _db.select(_db.playlists).get()) {
      final entries =
          await (_db.select(_db.playlistEntries)
                ..where((e) => e.playlistId.equals(p.id))
                ..orderBy([(e) => OrderingTerm.asc(e.position)]))
              .get();
      // "Mix (2)" (made by an earlier restore) counts as a "Mix" too.
      existing.putIfAbsent(_baseName(p.name), () => []).add([
        for (final e in entries) e.songId,
      ]);
    }
    final names = [
      for (final p in await _db.select(_db.playlists).get()) p.name,
    ];
    var playlistsAdded = 0;
    var playlistsKept = 0;
    for (final playlist in backup.playlists) {
      final found = [
        for (final entry in playlist.entries)
          if (match(entry.song) case final song?) (song, entry.addedAt),
      ];
      if (found.isEmpty && playlist.entries.isNotEmpty) continue;
      final ids = [for (final (song, _) in found) song.id];
      final same = existing[_baseName(playlist.name)] ?? const [];
      if (same.any((other) => _sameList(other, ids))) {
        playlistsKept++;
        continue;
      }
      final name = uniquePlaylistName(playlist.name, names);
      names.add(name);
      final id = await _db
          .into(_db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: name,
              createdAt: playlist.createdAt,
              updatedAt: playlist.updatedAt,
            ),
          );
      await _db.batch((b) {
        for (final (i, (song, addedAt)) in found.indexed) {
          b.insert(
            _db.playlistEntries,
            PlaylistEntriesCompanion.insert(
              playlistId: id,
              songId: song.id,
              songPath: song.path,
              position: i,
              addedAt: addedAt,
            ),
          );
        }
      });
      playlistsAdded++;
    }

    // Plays: all of them, also of songs that aren't here (their title and
    // artist keep the stats readable). A play already in the history
    // (same start and song) is skipped, so restoring twice adds nothing.
    final known = {
      for (final e in await _db.select(_db.playEvents).get())
        (e.startedAt, e.songPath),
    };
    var playsAdded = 0;
    var playsKept = 0;
    final sources = {for (final s in PlaySource.values) s.name: s};
    await _db.batch((b) {
      for (final play in backup.plays) {
        final song = match(play.song);
        final path = song?.path ?? play.song.path;
        if (!known.add((play.startedAt, path))) {
          playsKept++;
          continue;
        }
        b.insert(
          _db.playEvents,
          PlayEventsCompanion.insert(
            songId: Value(song?.id),
            songPath: path,
            title: play.song.title,
            artist: Value(play.song.artist),
            album: Value(play.song.album),
            startedAt: play.startedAt,
            listenedMs: play.listenedMs,
            durationMs: play.durationMs,
            completed: play.completed,
            source: sources[play.source] ?? PlaySource.songs,
          ),
        );
        playsAdded++;
      }
    });

    return RestoreReport(
      likesAdded: likesAdded,
      likesKept: likesKept,
      playlistsAdded: playlistsAdded,
      playlistsKept: playlistsKept,
      playsAdded: playsAdded,
      playsKept: playsKept,
      missingSongs: missing.length,
    );
  }

  static String _baseName(String name) =>
      name.replaceFirst(RegExp(r' \(\d+\)$'), '').toLowerCase();

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _restoreSettings(Map<String, Object> settings) async {
    for (final MapEntry(:key, value: type) in backupSettingTypes.entries) {
      final value = settings[key];
      if (value == null) continue;
      switch ((type, value)) {
        case (const (String), final String v):
          await _prefs.setString(key, v);
        case (const (int), final num v):
          await _prefs.setInt(key, v.toInt());
        case (const (double), final num v):
          await _prefs.setDouble(key, v.toDouble());
        case (const (bool), final bool v):
          await _prefs.setBool(key, v);
        case (const (List<String>), final List<String> v):
          await _prefs.setStringList(key, v);
        default:
          // A value of the wrong type (a damaged or edited file): skipped.
          break;
      }
    }
  }
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(documentFilesProvider),
  ),
);
