import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/features.dart';
import 'package:haraplay/core/storage/preferences.dart';
import 'package:haraplay/features/backup/domain/backup.dart';
import 'package:haraplay/features/equalizer/data/audio_effects.dart';
import 'package:haraplay/features/equalizer/domain/equalizer.dart';
import 'package:haraplay/features/player/data/player_audio.dart';
import 'package:just_audio/just_audio.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

/// Records everything sent to the player's effects.
class _RecordingEffects implements AudioEffectsSink {
  final applied = <Object>[];

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
  }) async => applied.add((equalizerEnabled, gains, loudnessDb));
}

const _fiveBands = AudioEffectsInfo(
  equalizer: EqualizerLayout(
    minDecibels: -15,
    maxDecibels: 15,
    bands: [60, 230, 910, 3600, 14000],
  ),
  loudness: true,
);

/// What a 0.1.0 user with the equalizer and loudness boost on has saved.
final _savedOn = const EqualizerSettings(
  enabled: true,
  presetId: 'rock',
  loudnessDb: 8,
).encode();

void main() {
  test('the equalizer is disabled in this build', () {
    expect(kEqualizerEnabled, isFalse);
  });

  group('setUpPlayerAudio', () {
    late int probes;
    late int equalizers;
    late int enhancers;

    setUp(() {
      probes = equalizers = enhancers = 0;
    });

    Future<PlayerAudio> setUpWith({bool? enabled}) async {
      final prefs = await createTestPreferences({'audio.equalizer': _savedOn});
      Future<AudioEffectsInfo> probe() async {
        probes++;
        return _fiveBands;
      }

      AndroidEqualizer newEqualizer() {
        equalizers++;
        return AndroidEqualizer();
      }

      AndroidLoudnessEnhancer newLoudness() {
        enhancers++;
        return AndroidLoudnessEnhancer();
      }

      return enabled == null
          ? setUpPlayerAudio(
              prefs,
              probe: probe,
              newEqualizer: newEqualizer,
              newLoudness: newLoudness,
            )
          : setUpPlayerAudio(
              prefs,
              enabled: enabled,
              probe: probe,
              newEqualizer: newEqualizer,
              newLoudness: newLoudness,
            );
    }

    test('flag off: no probe and no effect, even with settings saved '
        'as on', () async {
      final audio = await setUpWith();
      expect(probes, 0, reason: 'no effects probe');
      expect(equalizers, 0, reason: 'no AndroidEqualizer');
      expect(enhancers, 0, reason: 'no AndroidLoudnessEnhancer');
      expect(audio.mainEffects, isEmpty, reason: 'main player');
      expect(audio.tailEffects(), isEmpty, reason: 'crossfade tail player');
      expect(audio.info.equalizer, isNull);
      expect(audio.info.loudness, isFalse);
      expect(audio.sink, isA<NoAudioEffects>());
    });

    test('flag on (as in 0.1.0): both players get their own effects', () async {
      final audio = await setUpWith(enabled: true);
      expect(probes, 1);
      expect(audio.mainEffects, hasLength(2));
      expect(audio.tailEffects(), hasLength(2));
      expect((equalizers, enhancers), (2, 2));
    });
  });

  testWidgets('saved equalizer settings: no Equalizer row, nothing applied, '
      'kept stored', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final effects = _RecordingEffects();
    await pumpHaraApp(
      tester,
      prefs: {...onboardedPrefs, 'audio.equalizer': _savedOn},
      effectsInfo: _fiveBands,
      effectsSink: effects,
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('ReplayGain'), findsOneWidget);
    expect(find.text('Equalizer'), findsNothing);
    await tester.dragFrom(
      tester.getCenter(find.byType(Scaffold).last),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('qualizer'), findsNothing);
    expect(effects.applied, isEmpty);
    final prefs = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).last),
    ).read(sharedPreferencesProvider);
    expect(prefs.getString('audio.equalizer'), _savedOn);
  });

  testWidgets('a restored backup\'s equalizer settings are stored, '
      'not applied', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final effects = _RecordingEffects();
    final files = FakeDocumentFiles()
      ..toOpen = (
        name: 'b.json',
        path: null,
        bytes: Uint8List.fromList(
          utf8.encode(
            Backup(
              createdAt: DateTime(2026, 11),
              likes: const [],
              playlists: const [],
              plays: const [],
              settings: {'audio.equalizer': _savedOn},
            ).encode(),
          ),
        ),
      );
    await pumpHaraApp(
      tester,
      documentFiles: files,
      effectsInfo: _fiveBands,
      effectsSink: effects,
    );
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
      }
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Restore from a backup'), 200);
    await tester.ensureVisible(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore from a backup'));
    await settle();
    expect(find.text('Also restore settings'), findsOneWidget);
    expect(find.text('Colours, playback, library'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await settle();
    expect(find.textContaining('Settings restored'), findsOneWidget);
    final prefs = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).last),
    ).read(sharedPreferencesProvider);
    expect(prefs.getString('audio.equalizer'), _savedOn);
    expect(effects.applied, isEmpty);
  });
}
