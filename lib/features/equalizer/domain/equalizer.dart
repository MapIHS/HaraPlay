import 'dart:convert';
import 'dart:math' as math;

/// The device's equalizer: its gain range and band centre frequencies.
class EqualizerLayout {
  const EqualizerLayout({
    required this.minDecibels,
    required this.maxDecibels,
    required this.bands,
  });

  final double minDecibels;
  final double maxDecibels;

  /// Centre frequency of each band in Hz, low to high.
  final List<double> bands;

  double clamp(double gain) => gain.clamp(minDecibels, maxDecibels);
}

/// Which effects this device offers (probed before the player starts).
class AudioEffectsInfo {
  const AudioEffectsInfo({this.equalizer, this.loudness = false});

  static const none = AudioEffectsInfo();

  /// Null when the device has no equalizer.
  final EqualizerLayout? equalizer;
  final bool loudness;

  factory AudioEffectsInfo.fromChannel(Map<Object?, Object?>? map) {
    if (map == null) return none;
    final eq = map['equalizer'];
    EqualizerLayout? layout;
    if (eq is Map) {
      final bands = (eq['bands'] as List?)?.whereType<num>().toList() ?? [];
      final min = eq['minDecibels'];
      final max = eq['maxDecibels'];
      if (bands.isNotEmpty && min is num && max is num && max > min) {
        layout = EqualizerLayout(
          minDecibels: min.toDouble(),
          maxDecibels: max.toDouble(),
          bands: [for (final b in bands) b.toDouble()],
        );
      }
    }
    return AudioEffectsInfo(
      equalizer: layout,
      loudness: map['loudness'] == true,
    );
  }
}

/// A named equalizer curve. Gains are given at a few anchor frequencies and
/// interpolated on a log-frequency scale, so a preset fits any band layout.
class EqPreset {
  const EqPreset(this.id, this.label, this.curve);

  final String id;
  final String label;

  /// (frequency in Hz, gain in dB), low to high.
  final List<(double, double)> curve;

  /// Gain at [hz], held flat beyond the first and last anchors.
  double gainAt(double hz) {
    if (hz <= curve.first.$1) return curve.first.$2;
    if (hz >= curve.last.$1) return curve.last.$2;
    for (var i = 1; i < curve.length; i++) {
      final (f1, g1) = curve[i];
      if (hz <= f1) {
        final (f0, g0) = curve[i - 1];
        final t = (math.log(hz) - math.log(f0)) / (math.log(f1) - math.log(f0));
        return g0 + (g1 - g0) * t;
      }
    }
    return curve.last.$2;
  }
}

/// HaraPlay's own presets (Android's built-in ones vary per device and
/// aren't reachable through the player).
const eqPresets = [
  EqPreset('flat', 'Flat', [(60, 0), (14000, 0)]),
  EqPreset('bass', 'Bass boost', [(60, 6), (230, 4), (910, 0), (14000, 0)]),
  EqPreset('treble', 'Treble boost', [
    (60, 0),
    (910, 0),
    (3600, 4),
    (14000, 6),
  ]),
  EqPreset('vocal', 'Vocal', [
    (60, -2),
    (230, -1),
    (910, 3),
    (3600, 4),
    (14000, 1),
  ]),
  EqPreset('rock', 'Rock', [
    (60, 4),
    (230, 2),
    (910, -1),
    (3600, 2),
    (14000, 4),
  ]),
  EqPreset('electronic', 'Electronic', [
    (60, 5),
    (230, 2),
    (910, 0),
    (3600, 2),
    (14000, 5),
  ]),
  EqPreset('acoustic', 'Acoustic', [
    (60, 3),
    (230, 1),
    (910, 1),
    (3600, 2),
    (14000, 2),
  ]),
];

/// The id used for the user's own band gains.
const customPresetId = 'custom';

/// What the user chose; saved in preferences.
class EqualizerSettings {
  const EqualizerSettings({
    this.enabled = false,
    this.presetId = 'flat',
    this.customGains = const {},
    this.loudnessDb = 0,
  });

  final bool enabled;

  /// One of [eqPresets] or [customPresetId].
  final String presetId;

  /// Custom gains by band centre frequency (rounded Hz), so they survive
  /// a different band layout.
  final Map<int, double> customGains;

  /// Loudness boost in dB; 0 is off.
  final double loudnessDb;

  /// The highest loudness boost offered.
  static const maxLoudnessDb = 10.0;

  EqualizerSettings copyWith({
    bool? enabled,
    String? presetId,
    Map<int, double>? customGains,
    double? loudnessDb,
  }) => EqualizerSettings(
    enabled: enabled ?? this.enabled,
    presetId: presetId ?? this.presetId,
    customGains: customGains ?? this.customGains,
    loudnessDb: loudnessDb ?? this.loudnessDb,
  );

  /// The gain for each band of [layout].
  List<double> gainsFor(EqualizerLayout layout) {
    if (presetId == customPresetId) {
      return [
        for (final hz in layout.bands)
          layout.clamp(customGains[hz.round()] ?? 0),
      ];
    }
    final preset = eqPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => eqPresets.first,
    );
    return [for (final hz in layout.bands) layout.clamp(preset.gainAt(hz))];
  }

  String encode() => jsonEncode({
    'enabled': enabled,
    'preset': presetId,
    'custom': {for (final e in customGains.entries) '${e.key}': e.value},
    'loudness': loudnessDb,
  });

  static EqualizerSettings decode(String? json) {
    if (json == null) return const EqualizerSettings();
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final custom = map['custom'] as Map<String, dynamic>? ?? const {};
      final preset = map['preset'] as String? ?? 'flat';
      final known =
          preset == customPresetId || eqPresets.any((p) => p.id == preset);
      return EqualizerSettings(
        enabled: map['enabled'] == true,
        presetId: known ? preset : 'flat',
        customGains: {
          for (final e in custom.entries)
            if (int.tryParse(e.key) != null && e.value is num)
              int.parse(e.key): (e.value as num).toDouble(),
        },
        loudnessDb: ((map['loudness'] as num?) ?? 0).toDouble().clamp(
          0,
          maxLoudnessDb,
        ),
      );
    } on Object {
      return const EqualizerSettings();
    }
  }
}

/// "60 Hz", "910 Hz", "3.6 kHz", "14 kHz".
String formatFrequency(double hz) {
  if (hz < 1000) return '${hz.round()} Hz';
  final khz = hz / 1000;
  final text = khz >= 10 || khz == khz.roundToDouble()
      ? khz.round().toString()
      : khz.toStringAsFixed(1);
  return '$text kHz';
}

/// "+3 dB", "0 dB", "−2.5 dB".
String formatGain(double db) {
  final rounded = (db * 2).round() / 2;
  if (rounded == 0) return '0 dB';
  final text = rounded == rounded.roundToDouble()
      ? rounded.abs().round().toString()
      : rounded.abs().toStringAsFixed(1);
  return '${rounded > 0 ? '+' : '−'}$text dB';
}
