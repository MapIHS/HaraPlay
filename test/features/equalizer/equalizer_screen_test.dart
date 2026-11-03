import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/equalizer/data/audio_effects.dart';
import 'package:haraplay/features/equalizer/domain/equalizer.dart';

import '../../helpers/test_app.dart';

/// Records what the screen applies.
class RecordingEffects implements AudioEffectsSink {
  final applied = <(bool, List<double>, double)>[];

  /// Whether each change asked for the volume dip (discrete changes).
  final smooth = <bool>[];

  (bool, List<double>, double) get last => applied.last;

  @override
  Future<void> apply({
    required bool equalizerEnabled,
    required List<double> gains,
    required double loudnessDb,
    bool smooth = true,
  }) async {
    applied.add((equalizerEnabled, gains, loudnessDb));
    this.smooth.add(smooth);
  }

  @override
  bool switchesOn({
    required bool equalizerEnabled,
    required double loudnessDb,
  }) => false;
}

void main() {
  const fiveBands = AudioEffectsInfo(
    equalizer: EqualizerLayout(
      minDecibels: -15,
      maxDecibels: 15,
      bands: [60, 230, 910, 3600, 14000],
    ),
    loudness: true,
  );

  Future<RecordingEffects> openEqualizer(
    WidgetTester tester, {
    AudioEffectsInfo info = fiveBands,
    Map<String, Object> prefs = onboardedPrefs,
  }) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2280)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final effects = RecordingEffects();
    await pumpHaraApp(
      tester,
      effectsInfo: info,
      effectsSink: effects,
      prefs: prefs,
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equalizer'));
    await tester.pumpAndSettle();
    return effects;
  }

  testWidgets('a preset switches the equalizer on and applies its curve', (
    tester,
  ) async {
    final effects = await openEqualizer(tester);
    expect(find.text('Equalizer'), findsWidgets);
    expect(find.text('60 Hz'), findsOneWidget);
    expect(find.text('14 kHz'), findsOneWidget);

    await tester.tap(find.text('Bass boost'));
    await tester.pumpAndSettle();
    final (enabled, gains, loudness) = effects.last;
    expect(enabled, isTrue);
    expect(gains, [6, 4, 0, 0, 0]);
    expect(loudness, 0);
    expect(find.text('+6 dB'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(effects.last.$1, isFalse);
  });

  testWidgets('moving a band makes a custom curve', (tester) async {
    final effects = await openEqualizer(tester);
    // The preset row scrolls sideways.
    await tester.ensureVisible(find.text('Rock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();

    // Drag the 910 Hz slider (the third) to the top.
    final slider = find.byType(Slider).at(2);
    await tester.drag(slider, const Offset(0, -300));
    await tester.pumpAndSettle();

    final (enabled, gains, _) = effects.last;
    expect(enabled, isTrue);
    expect(gains[2], 15);
    // The other bands keep the Rock curve.
    expect(gains[0], 4);
    expect(gains[4], 4);
    expect(find.text('Custom'), findsOneWidget);
    // The preset was a discrete change (the volume dips around it); a
    // band being dragged is not, so it can be heard while moving.
    expect(effects.smooth.first, isTrue);
    expect(effects.smooth.last, isFalse);
  });

  testWidgets('loudness boost, reset, and settings are kept', (tester) async {
    final effects = await openEqualizer(tester);
    final loudness = find.byType(Slider).last;
    await tester.drag(loudness, const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(effects.last.$3, EqualizerSettings.maxLoudnessDb);
    expect(find.text('+10 dB'), findsOneWidget);

    // Back in Settings the tile sums it up.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Loudness +10 dB'), findsOneWidget);

    await tester.tap(find.text('Equalizer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(effects.last.$3, 0);
  });

  testWidgets('saved settings are shown when the screen opens', (tester) async {
    const saved = EqualizerSettings(enabled: true, presetId: 'vocal');
    await openEqualizer(
      tester,
      prefs: {...onboardedPrefs, 'audio.equalizer': saved.encode()},
    );
    final vocal = find.bySemanticsLabel('Vocal');
    expect(tester.getSemantics(vocal), isSemantics(isSelected: true));
  });

  testWidgets('no effects at all: says so instead of showing controls', (
    tester,
  ) async {
    await openEqualizer(tester, info: AudioEffectsInfo.none);
    expect(find.text('No equalizer on this phone'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('loudness only: the equalizer part is explained', (tester) async {
    await openEqualizer(tester, info: const AudioEffectsInfo(loudness: true));
    expect(find.textContaining('no equalizer for apps'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget); // loudness only
  });
}
