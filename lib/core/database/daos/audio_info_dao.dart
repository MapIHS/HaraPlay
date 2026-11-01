import 'package:drift/drift.dart';

import '../../../features/audio_info/domain/audio_info.dart';
import '../app_database.dart';

part 'audio_info_dao.g.dart';

/// The `song_tech_info` cache: header details and ReplayGain per song.
@DriftAccessor(tables: [SongTechInfo, Songs])
class AudioInfoDao extends DatabaseAccessor<AppDatabase>
    with _$AudioInfoDaoMixin {
  AudioInfoDao(super.attachedDatabase);

  /// The cached info for [songId] if it was read from this [version] of
  /// the file (its date_modified); null when it must be read (again).
  Future<AudioFileInfo?> cached(int songId, {required int version}) async {
    final row =
        await (select(songTechInfo)..where(
              (t) =>
                  t.songId.equals(songId) &
                  t.sourceDateModified.equals(version),
            ))
            .getSingleOrNull();
    return row == null ? null : _toInfo(row);
  }

  /// Stores [info] for [songId]. Does nothing for a song that is gone.
  Future<void> save(
    int songId, {
    required int version,
    required AudioFileInfo info,
    required DateTime at,
  }) async {
    final exists = await (select(
      songs,
    )..where((s) => s.id.equals(songId))).getSingleOrNull();
    if (exists == null) return;
    await into(songTechInfo).insertOnConflictUpdate(
      SongTechInfoCompanion.insert(
        songId: Value(songId),
        sourceDateModified: version,
        sampleRate: Value(info.sampleRate),
        bitDepth: Value(info.bitDepth),
        bitrate: Value(info.bitrate),
        channels: Value(info.channels),
        codec: Value(info.codec),
        trackGain: Value(info.replayGain.trackGain),
        trackPeak: Value(info.replayGain.trackPeak),
        albumGain: Value(info.replayGain.albumGain),
        albumPeak: Value(info.replayGain.albumPeak),
        readAt: at.millisecondsSinceEpoch,
      ),
    );
  }

  static AudioFileInfo _toInfo(SongTechInfoRow row) => AudioFileInfo(
    codec: row.codec,
    sampleRate: row.sampleRate,
    bitDepth: row.bitDepth,
    bitrate: row.bitrate,
    channels: row.channels,
    replayGain: ReplayGain(
      trackGain: row.trackGain,
      trackPeak: row.trackPeak,
      albumGain: row.albumGain,
      albumPeak: row.albumPeak,
    ),
  );
}
