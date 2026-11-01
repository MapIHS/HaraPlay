import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/audio_info/domain/audio_info.dart';
import 'package:haraplay/features/player/domain/queue_song.dart';
import 'package:haraplay/features/player/presentation/mini_player.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  const path = '/storage/emulated/0/Music/song1.mp3';
  const info = AudioFileInfo(
    codec: 'FLAC',
    sampleRate: 96000,
    bitDepth: 24,
    channels: 2,
    bitrate: 2400000,
    replayGain: ReplayGain(trackGain: -7.25, albumGain: -6.1),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Now Playing shows the format badge; Song info the details', (
    tester,
  ) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2280)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final db = createTestDatabase();
    await db.libraryDao.applyScan([mediaSong(1, title: 'Night Drive')]);
    final player = FakePlayer();
    await pumpHaraApp(
      tester,
      database: db,
      player: player,
      audioInfo: FakeAudioInfo({path: info}),
    );
    final row = (await tester.runAsync(() => db.select(db.songs).getSingle()))!;
    await player.playSongs([QueueSong.fromRow(row)], source: PlaySource.songs);
    await settle(tester);

    await tester.tap(find.byType(MiniPlayer));
    await settle(tester);
    expect(find.text('FLAC · 24-bit / 96 kHz'), findsOneWidget);

    await tester.tap(find.byTooltip('Song actions'));
    await settle(tester);
    await tester.tap(find.text('Song info'));
    await settle(tester);
    expect(find.text('FLAC'), findsOneWidget);
    expect(find.text('24-bit / 96 kHz'), findsOneWidget);
    expect(find.text('Stereo'), findsOneWidget);
    expect(find.text('2400 kbps'), findsOneWidget);
    expect(find.text('Track −7.3 dB · Album −6.1 dB'), findsOneWidget);
  });

  testWidgets('Settings sets the ReplayGain mode on the player', (
    tester,
  ) async {
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('ReplayGain'), findsOneWidget);

    await tester.tap(find.text('ReplayGain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();
    expect(player.replayGainMode, ReplayGainMode.album);
    expect(find.textContaining('Album · Albums at the same'), findsOneWidget);
  });
}
