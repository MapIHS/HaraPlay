import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/equalizer/domain/equalizer.dart';

void main() {
  // A common Android layout: five bands, ±15 dB.
  const layout = EqualizerLayout(
    minDecibels: -15,
    maxDecibels: 15,
    bands: [60, 230, 910, 3600, 14000],
  );

  EqPreset preset(String id) => eqPresets.firstWhere((p) => p.id == id);

  test('presets hit their anchors and interpolate on a log scale', () {
    final bass = preset('bass');
    expect(bass.gainAt(60), 6);
    expect(bass.gainAt(230), 4);
    expect(bass.gainAt(20), 6); // held below the first anchor
    expect(bass.gainAt(20000), 0); // and above the last
    // Halfway between 60 and 230 Hz on a log scale is ~117 Hz.
    expect(bass.gainAt(117.5), closeTo(5, 0.05));
  });

  test('every preset fits a 5-band and a 10-band layout', () {
    const ten = EqualizerLayout(
      minDecibels: -12,
      maxDecibels: 12,
      bands: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
    );
    for (final p in eqPresets) {
      final settings = EqualizerSettings(presetId: p.id);
      expect(settings.gainsFor(layout), hasLength(5));
      expect(settings.gainsFor(ten), hasLength(10));
    }
    expect(
      const EqualizerSettings(presetId: 'flat').gainsFor(ten),
      everyElement(0),
    );
  });

  test('gains are clamped to what the device allows', () {
    const narrow = EqualizerLayout(
      minDecibels: -3,
      maxDecibels: 3,
      bands: [60, 14000],
    );
    expect(const EqualizerSettings(presetId: 'bass').gainsFor(narrow), [3, 0]);
    expect(
      const EqualizerSettings(
        presetId: customPresetId,
        customGains: {60: -9, 14000: 2},
      ).gainsFor(narrow),
      [-3, 2],
    );
  });

  test('custom gains are kept by frequency; unknown bands are flat', () {
    const s = EqualizerSettings(
      presetId: customPresetId,
      customGains: {60: 4, 910: -2},
    );
    expect(s.gainsFor(layout), [4, 0, -2, 0, 0]);
  });

  test('settings survive a save and reload; bad data falls back', () {
    const s = EqualizerSettings(
      enabled: true,
      presetId: customPresetId,
      customGains: {60: 4.5, 14000: -1},
      loudnessDb: 6,
    );
    final back = EqualizerSettings.decode(s.encode());
    expect(back.enabled, isTrue);
    expect(back.presetId, customPresetId);
    expect(back.customGains, {60: 4.5, 14000: -1});
    expect(back.loudnessDb, 6);

    expect(EqualizerSettings.decode(null).enabled, isFalse);
    expect(EqualizerSettings.decode('not json').presetId, 'flat');
    expect(
      EqualizerSettings.decode('{"preset":"gone","loudness":99}').presetId,
      'flat',
    );
    expect(
      EqualizerSettings.decode('{"loudness":99}').loudnessDb,
      EqualizerSettings.maxLoudnessDb,
    );
  });

  test('platform answers are parsed defensively', () {
    final info = AudioEffectsInfo.fromChannel({
      'equalizer': {
        'minDecibels': -15.0,
        'maxDecibels': 15.0,
        'bands': [60.0, 230.0],
      },
      'loudness': true,
    });
    expect(info.equalizer!.bands, [60, 230]);
    expect(info.loudness, isTrue);

    final none = AudioEffectsInfo.fromChannel({
      'equalizer': {'minDecibels': 0, 'maxDecibels': 0, 'bands': <num>[]},
      'loudness': false,
    });
    expect(none.equalizer, isNull);
    expect(AudioEffectsInfo.fromChannel(null).loudness, isFalse);
  });

  test('labels', () {
    expect(formatFrequency(60), '60 Hz');
    expect(formatFrequency(910), '910 Hz');
    expect(formatFrequency(3600), '3.6 kHz');
    expect(formatFrequency(14000), '14 kHz');
    expect(formatFrequency(1000), '1 kHz');
    expect(formatGain(0), '0 dB');
    expect(formatGain(3), '+3 dB');
    expect(formatGain(-2.5), '−2.5 dB');
    expect(formatGain(0.1), '0 dB');
  });
}
