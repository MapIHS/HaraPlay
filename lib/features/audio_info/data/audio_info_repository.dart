import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/audio_info_dao.dart';
import '../domain/audio_info.dart';
import 'audio_header_reader.dart';

/// Which file (and which version of it) to describe.
typedef AudioInfoKey = ({int id, String path, int version});

/// Header details and ReplayGain for a song, for the player and the UI.
abstract interface class AudioInfoSource {
  /// Never throws; unreadable files give [AudioFileInfo.unreadable].
  Future<AudioFileInfo> infoFor(AudioInfoKey song);
}

/// Reads one file's header, off the UI isolate.
typedef AudioFileReader = Future<AudioFileInfo> Function(String path);

Future<AudioFileInfo> _readInIsolate(String path) =>
    Isolate.run(() => readAudioFileInfo(path));

/// Reads headers on demand and caches them in memory and in
/// `song_tech_info`, keyed by the file's version, so a re-tagged file is
/// read again.
class AudioInfoRepository implements AudioInfoSource {
  AudioInfoRepository(
    this._dao, {
    this._reader = _readInIsolate,
    this._clock = DateTime.now,
  });

  final AudioInfoDao _dao;
  final AudioFileReader _reader;
  final DateTime Function() _clock;

  /// Recently used songs; enough for the queue around the current one.
  static const _memoryLimit = 64;
  final _memory = <AudioInfoKey, Future<AudioFileInfo>>{};

  @override
  Future<AudioFileInfo> infoFor(AudioInfoKey song) {
    final known = _memory.remove(song);
    final future = known ?? _load(song);
    _memory[song] = future; // most recent last
    if (_memory.length > _memoryLimit) _memory.remove(_memory.keys.first);
    return future;
  }

  Future<AudioFileInfo> _load(AudioInfoKey song) async {
    try {
      final cached = await _dao.cached(song.id, version: song.version);
      if (cached != null) return cached;
      final info = await _reader(song.path);
      // Unreadable files aren't stored, so a passing problem (e.g. no
      // access yet) doesn't stick.
      if (info.codec != null) {
        await _dao.save(
          song.id,
          version: song.version,
          info: info,
          at: _clock(),
        );
      }
      return info;
    } on Object catch (e) {
      debugPrint('HaraPlay audio info: $e');
      return AudioFileInfo.unreadable;
    }
  }
}

final audioInfoSourceProvider = Provider<AudioInfoSource>(
  (ref) => AudioInfoRepository(ref.watch(appDatabaseProvider).audioInfoDao),
);

/// One song's details, for Now Playing and Song info.
final audioInfoProvider = FutureProvider.autoDispose
    .family<AudioFileInfo, AudioInfoKey>(
      (ref, song) => ref.watch(audioInfoSourceProvider).infoFor(song),
    );
