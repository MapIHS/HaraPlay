import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/audio_info/data/audio_info_repository.dart';
import 'package:haraplay/features/audio_info/domain/audio_info.dart';
import 'package:haraplay/features/player/data/player_volume.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_database.dart';

const _tagged = AudioFileInfo(
  codec: 'FLAC',
  replayGain: ReplayGain(trackGain: -6, albumGain: -12),
);

AudioInfoKey _key(int id, {int version = 1}) =>
    (id: id, path: '/m/$id.flac', version: version);

void main() {
  group('replayGainVolume', () {
    test('turns decibels into a volume factor per mode', () {
      const gain = ReplayGain(trackGain: -6.0206, albumGain: -12.0412);
      expect(replayGainVolume(gain, ReplayGainMode.off), 1);
      expect(replayGainVolume(gain, ReplayGainMode.track), closeTo(0.5, 1e-4));
      expect(replayGainVolume(gain, ReplayGainMode.album), closeTo(0.25, 1e-4));
    });

    test('falls back to the other value, and never raises the volume', () {
      expect(
        replayGainVolume(
          const ReplayGain(albumGain: -6.0206),
          ReplayGainMode.track,
        ),
        closeTo(0.5, 1e-4),
      );
      expect(
        replayGainVolume(const ReplayGain(trackGain: 4), ReplayGainMode.album),
        1,
      );
      expect(replayGainVolume(ReplayGain.none, ReplayGainMode.track), 1);
    });

    test('parses tag text', () {
      expect(parseGain('-6.40 dB'), -6.4);
      expect(parseGain('+1,5 dB'), 1.5);
      expect(parseGain(' 3 '), 3);
      expect(parseGain('loud'), isNull);
      expect(parseGain('-120 dB'), isNull);
      expect(parsePeak('0.988251'), 0.988251);
      expect(parsePeak('0'), isNull);
    });
  });

  test('badges and Song info rows', () {
    expect(
      techBadge(
        const AudioFileInfo(codec: 'ALAC', bitDepth: 16, sampleRate: 44100),
      ),
      'ALAC · 16-bit / 44.1 kHz',
    );
    expect(
      techBadge(const AudioFileInfo(codec: 'Opus', sampleRate: 48000)),
      'Opus · 48 kHz',
    );
    expect(techBadge(const AudioFileInfo(codec: 'AAC')), 'AAC');
    expect(techBadge(AudioFileInfo.unreadable), isNull);
    expect(
      audioInfoRows(
        const AudioFileInfo(
          codec: 'MP3',
          sampleRate: 44100,
          channels: 2,
          bitrate: 245000,
          replayGain: ReplayGain(trackGain: -7.25, albumGain: 1.5),
        ),
      ),
      [
        ('Quality', '44.1 kHz'),
        ('Channels', 'Stereo'),
        ('Bitrate', '245 kbps'),
        ('ReplayGain', 'Track −7.3 dB · Album +1.5 dB'),
      ],
    );
  });

  group('PlayerVolume', () {
    late List<double> sent;
    late FakeAudioInfo source;
    late PlayerVolume volume;

    setUp(() {
      sent = [];
      source = FakeAudioInfo({
        '/m/1.flac': _tagged,
        '/m/2.flac': const AudioFileInfo(
          codec: 'FLAC',
          replayGain: ReplayGain(trackGain: -20),
        ),
      });
      volume = PlayerVolume(
        setVolume: (v) async => sent.add(v),
        source: source,
      );
    });

    test('is full volume while off, without reading any tags', () async {
      await volume.songChanged(_key(1));
      expect(volume.volume, 1);
      expect(source.requested, isEmpty);
    });

    test('applies the mode, and reads the next song ahead', () async {
      await volume.setMode(ReplayGainMode.track);
      await volume.songChanged(_key(1), next: _key(2));
      expect(volume.volume, closeTo(0.501, 1e-3));
      expect(source.requested, containsAll([_key(1), _key(2)]));

      // The next song's gain is known, so it applies at once.
      final reads = source.requested.length;
      await volume.songChanged(_key(2));
      expect(volume.volume, closeTo(0.1, 1e-3));
      expect(source.requested, hasLength(reads));

      await volume.setMode(ReplayGainMode.album); // no album gain: track
      expect(volume.volume, closeTo(0.1, 1e-3));
      await volume.setMode(ReplayGainMode.off);
      expect(sent.last, 1);
    });

    test('multiplies with the sleep timer fade', () async {
      await volume.setMode(ReplayGainMode.album);
      await volume.songChanged(_key(1));
      await volume.setFade(0.5);
      expect(sent.last, closeTo(0.5 * 0.251, 1e-3));
      await volume.setFade(1);
      expect(sent.last, closeTo(0.251, 1e-3));
    });

    test('an untagged song plays at full volume', () async {
      await volume.setMode(ReplayGainMode.track);
      await volume.songChanged(_key(1));
      await volume.songChanged(_key(3));
      expect(volume.volume, 1);
    });
  });

  group('AudioInfoRepository', () {
    late AppDatabase db;
    late List<String> reads;
    late AudioInfoRepository repository;

    setUp(() async {
      db = createTestDatabase();
      addTearDown(db.close);
      await db.libraryDao.applyScan([mediaSong(1), mediaSong(2)]);
      reads = [];
      repository = AudioInfoRepository(
        db.audioInfoDao,
        reader: (path) async {
          reads.add(path);
          return path.endsWith('1.flac') ? _tagged : AudioFileInfo.unreadable;
        },
        clock: () => DateTime(2026, 11),
      );
    });

    test('reads a file once and caches it in the database', () async {
      expect(await repository.infoFor(_key(1)), _tagged);
      expect(await repository.infoFor(_key(1)), _tagged);
      expect(reads, ['/m/1.flac']);

      // A new repository (next launch) finds it in the database.
      final next = AudioInfoRepository(
        db.audioInfoDao,
        reader: (path) async => throw StateError('should not read'),
      );
      expect(await next.infoFor(_key(1)), _tagged);
      final row = await db.select(db.songTechInfo).getSingle();
      expect(row.sourceDateModified, 1);
      expect(row.trackGain, -6);
    });

    test('reads again when the file changed', () async {
      await repository.infoFor(_key(1));
      await repository.infoFor(_key(1, version: 2));
      expect(reads, ['/m/1.flac', '/m/1.flac']);
      final row = await db.select(db.songTechInfo).getSingle();
      expect(row.sourceDateModified, 2);
    });

    test('unreadable files are not stored', () async {
      expect(await repository.infoFor(_key(2)), AudioFileInfo.unreadable);
      expect(await db.select(db.songTechInfo).get(), isEmpty);
    });

    test('a deleted song takes its row along', () async {
      await repository.infoFor(_key(1));
      await db.libraryDao.applyScan([mediaSong(2)]);
      expect(
        await db.select(db.songTechInfo).get(),
        isEmpty,
        reason: 'ON DELETE CASCADE',
      );
      expect(await db.audioInfoDao.cached(1, version: 1), isNull);
      // Saving for a song that is gone does nothing.
      await db.audioInfoDao.save(
        1,
        version: 1,
        info: _tagged,
        at: DateTime(2026),
      );
      expect(await db.select(db.songTechInfo).get(), isEmpty);
    });
  });
}
