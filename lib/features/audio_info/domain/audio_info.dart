import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What a file's own header says about its audio, plus its ReplayGain
/// tags. Every field is optional: readers fill in what the format has.
@immutable
class AudioFileInfo {
  const AudioFileInfo({
    this.codec,
    this.sampleRate,
    this.bitDepth,
    this.bitrate,
    this.channels,
    this.replayGain = ReplayGain.none,
  });

  static const unreadable = AudioFileInfo();

  /// Short codec name: FLAC, MP3, AAC, ALAC, Opus, Vorbis, PCM.
  final String? codec;

  /// Hz.
  final int? sampleRate;

  /// Bits per sample; lossless formats only.
  final int? bitDepth;

  /// Average bits per second.
  final int? bitrate;
  final int? channels;
  final ReplayGain replayGain;

  bool get lossless => const {'FLAC', 'ALAC', 'PCM'}.contains(codec);

  AudioFileInfo copyWith({int? bitrate, ReplayGain? replayGain}) =>
      AudioFileInfo(
        codec: codec,
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        bitrate: bitrate ?? this.bitrate,
        channels: channels,
        replayGain: replayGain ?? this.replayGain,
      );

  @override
  bool operator ==(Object other) =>
      other is AudioFileInfo &&
      other.codec == codec &&
      other.sampleRate == sampleRate &&
      other.bitDepth == bitDepth &&
      other.bitrate == bitrate &&
      other.channels == channels &&
      other.replayGain == replayGain;

  @override
  int get hashCode =>
      Object.hash(codec, sampleRate, bitDepth, bitrate, channels, replayGain);

  @override
  String toString() =>
      'AudioFileInfo($codec, $sampleRate Hz, $bitDepth bit, $bitrate bps, '
      '$channels ch, $replayGain)';
}

/// ReplayGain tags: decibels to add, and the loudest sample (1.0 = full
/// scale).
@immutable
class ReplayGain {
  const ReplayGain({
    this.trackGain,
    this.trackPeak,
    this.albumGain,
    this.albumPeak,
  });

  static const none = ReplayGain();

  final double? trackGain;
  final double? trackPeak;
  final double? albumGain;
  final double? albumPeak;

  bool get isEmpty => trackGain == null && albumGain == null;

  @override
  bool operator ==(Object other) =>
      other is ReplayGain &&
      other.trackGain == trackGain &&
      other.trackPeak == trackPeak &&
      other.albumGain == albumGain &&
      other.albumPeak == albumPeak;

  @override
  int get hashCode => Object.hash(trackGain, trackPeak, albumGain, albumPeak);

  @override
  String toString() =>
      'ReplayGain(track $trackGain / $trackPeak, album $albumGain / $albumPeak)';
}

/// Which ReplayGain value evens out the volume.
enum ReplayGainMode {
  off('Off'),

  /// Every song at the same loudness (best for shuffle).
  track('Track'),

  /// Albums at the same loudness, keeping the steps between their songs.
  album('Album');

  const ReplayGainMode(this.label);

  final String label;
}

/// The player volume (0–1) for a song with [gain] in [mode]. Each mode
/// falls back to the other value when its own is missing.
///
/// The player can only lower its volume, so a positive gain (a quiet
/// master) leaves the song at full volume; most songs are tagged with a
/// negative gain. Because the result never exceeds 1, the peak can't clip
/// and isn't needed.
double replayGainVolume(ReplayGain gain, ReplayGainMode mode) {
  final db = switch (mode) {
    ReplayGainMode.off => null,
    ReplayGainMode.track => gain.trackGain ?? gain.albumGain,
    ReplayGainMode.album => gain.albumGain ?? gain.trackGain,
  };
  if (db == null || db >= 0) return 1;
  return math.pow(10, db / 20).toDouble().clamp(0.0, 1.0);
}

/// "-6.4 dB" from a ReplayGain tag value such as "-6.40 dB" or "+1.2".
double? parseGain(String? text) {
  final match = RegExp(r'^\s*([+-]?\d+(?:[.,]\d+)?)').firstMatch(text ?? '');
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  // Tags outside this range are broken; ignore them.
  return value == null || value.abs() > 60 ? null : value;
}

/// A peak tag ("0.988251"); null if missing or nonsense.
double? parsePeak(String? text) {
  final value = double.tryParse(text?.trim().replaceAll(',', '.') ?? '');
  return value == null || value <= 0 || value > 10 ? null : value;
}

/// "44.1 kHz", "96 kHz".
String formatSampleRate(int hz) {
  final khz = hz / 1000;
  final text = khz == khz.roundToDouble()
      ? khz.round().toString()
      : khz.toStringAsFixed(1);
  return '$text kHz';
}

/// "320 kbps".
String formatBitrate(int bps) => '${(bps / 1000).round()} kbps';

/// "+3.5 dB" / "-6.4 dB".
String formatReplayGain(double db) =>
    '${db > 0
        ? '+'
        : db < 0
        ? '−'
        : ''}${db.abs().toStringAsFixed(1)} dB';

/// The Now Playing badge: "FLAC · 24-bit / 96 kHz" for lossless files,
/// "MP3 · 320 kbps" for lossy ones. Null when the header told us nothing.
String? techBadge(AudioFileInfo info) {
  final codec = info.codec;
  if (codec == null) return null;
  final details = info.lossless
      ? [
          if (info.bitDepth case final bits?) '$bits-bit',
          if (info.sampleRate case final rate?) formatSampleRate(rate),
        ].join(' / ')
      : switch (info.bitrate) {
          final bps? => formatBitrate(bps),
          null => switch (info.sampleRate) {
            final rate? => formatSampleRate(rate),
            null => '',
          },
        };
  return details.isEmpty ? codec : '$codec · $details';
}

/// "Stereo", "Mono", "6 channels".
String formatChannels(int channels) => switch (channels) {
  1 => 'Mono',
  2 => 'Stereo',
  _ => '$channels channels',
};

/// Song info rows (label, value) beyond the format itself.
List<(String, String)> audioInfoRows(AudioFileInfo info) {
  final gain = info.replayGain;
  return [
    if (info.sampleRate != null || info.bitDepth != null)
      (
        'Quality',
        [
          if (info.bitDepth case final bits?) '$bits-bit',
          if (info.sampleRate case final rate?) formatSampleRate(rate),
        ].join(' / '),
      ),
    if (info.channels case final channels? when channels > 0)
      ('Channels', formatChannels(channels)),
    if (info.bitrate case final bps?) ('Bitrate', formatBitrate(bps)),
    if (!gain.isEmpty)
      (
        'ReplayGain',
        [
          if (gain.trackGain case final db?) 'Track ${formatReplayGain(db)}',
          if (gain.albumGain case final db?) 'Album ${formatReplayGain(db)}',
        ].join(' · '),
      ),
  ];
}
