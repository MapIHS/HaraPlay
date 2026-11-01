// The field names follow Android's `system_<palette>_<shade>` resources.
// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The wallpaper-based system colours (Material You, Android 12+) that
/// the "Wallpaper" palette uses. Shade 10 is the lightest, 900 the darkest.
@immutable
class SystemTones {
  const SystemTones._(this._tones);

  /// The channel's keys.
  static const keys = [
    'accent1_200',
    'accent1_600',
    'neutral1_10',
    'neutral1_50',
    'neutral1_800',
    'neutral1_900',
    'neutral2_50',
    'neutral2_100',
    'neutral2_200',
    'neutral2_400',
    'neutral2_600',
  ];

  /// Reads the channel's reply (ARGB ints by key); null if any is missing.
  static SystemTones? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final tones = <String, Color>{};
    for (final key in keys) {
      final value = map[key];
      if (value is! int) return null;
      tones[key] = Color(value);
    }
    return SystemTones._(tones);
  }

  final Map<String, Color> _tones;

  Color get accent1_200 => _tones['accent1_200']!;
  Color get accent1_600 => _tones['accent1_600']!;
  Color get neutral1_10 => _tones['neutral1_10']!;
  Color get neutral1_50 => _tones['neutral1_50']!;
  Color get neutral1_800 => _tones['neutral1_800']!;
  Color get neutral1_900 => _tones['neutral1_900']!;
  Color get neutral2_50 => _tones['neutral2_50']!;
  Color get neutral2_100 => _tones['neutral2_100']!;
  Color get neutral2_200 => _tones['neutral2_200']!;
  Color get neutral2_400 => _tones['neutral2_400']!;
  Color get neutral2_600 => _tones['neutral2_600']!;

  @override
  bool operator ==(Object other) =>
      other is SystemTones &&
      keys.every((key) => other._tones[key] == _tones[key]);

  @override
  int get hashCode => Object.hashAll([for (final key in keys) _tones[key]]);
}

/// Dart side of `haraplay/system` (see `SystemColorsPlugin.kt`).
class SystemTonesChannel {
  const SystemTonesChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('haraplay/system');

  final MethodChannel _channel;

  /// The current wallpaper tones, or null before Android 12 (or on error).
  Future<SystemTones?> read() async {
    try {
      return SystemTones.fromMap(
        await _channel.invokeMapMethod<Object?, Object?>('systemTones'),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
