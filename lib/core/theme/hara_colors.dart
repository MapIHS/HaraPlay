import 'package:flutter/material.dart';

/// Semantic colour tokens for HaraPlay.
///
/// Widgets read colours from here (via [HaraColors.of]) instead of hard-coding
/// values, so palettes and light/dark modes can be swapped in one place.
@immutable
class HaraColors extends ThemeExtension<HaraColors> {
  const HaraColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.onPrimary,
    required this.emphasis,
    required this.foreground,
    required this.mutedForeground,
    required this.border,
    required this.shadow,
    required this.overlay,
    required this.mint,
    required this.sky,
    required this.lilac,
    required this.coral,
    required this.danger,
    required this.onDanger,
  });

  final Brightness brightness;

  /// Page background.
  final Color background;

  /// Cards, sheets, inputs.
  final Color surface;

  /// Containers, pressed rows, placeholders.
  final Color surfaceAlt;

  /// Brand fill: play button, active tab, current queue row.
  /// Use only as a *fill*; it is too light for text or thin strokes on
  /// light backgrounds — use [emphasis] for those.
  final Color primary;
  final Color onPrimary;

  /// Brand hue dark enough for icons, thin lines and slider tracks on
  /// [background] / [surface].
  final Color emphasis;

  final Color foreground;
  final Color mutedForeground;

  /// Outline colour for bordered surfaces.
  final Color border;

  /// Hard offset shadow colour.
  final Color shadow;

  /// Modal barrier / scrim.
  final Color overlay;

  // Pastel accents for chips, charts and artwork placeholders. Text on them
  // uses [foreground].
  final Color mint;
  final Color sky;
  final Color lilac;
  final Color coral;

  final Color danger;
  final Color onDanger;

  List<Color> get accents => [mint, sky, lilac, coral];

  static HaraColors of(BuildContext context) =>
      Theme.of(context).extension<HaraColors>()!;

  @override
  HaraColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? onPrimary,
    Color? emphasis,
    Color? foreground,
    Color? mutedForeground,
    Color? border,
    Color? shadow,
    Color? overlay,
    Color? mint,
    Color? sky,
    Color? lilac,
    Color? coral,
    Color? danger,
    Color? onDanger,
  }) {
    return HaraColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      emphasis: emphasis ?? this.emphasis,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      mint: mint ?? this.mint,
      sky: sky ?? this.sky,
      lilac: lilac ?? this.lilac,
      coral: coral ?? this.coral,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
    );
  }

  @override
  HaraColors lerp(HaraColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return HaraColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      emphasis: mix(emphasis, other.emphasis),
      foreground: mix(foreground, other.foreground),
      mutedForeground: mix(mutedForeground, other.mutedForeground),
      border: mix(border, other.border),
      shadow: mix(shadow, other.shadow),
      overlay: mix(overlay, other.overlay),
      mint: mix(mint, other.mint),
      sky: mix(sky, other.sky),
      lilac: mix(lilac, other.lilac),
      coral: mix(coral, other.coral),
      danger: mix(danger, other.danger),
      onDanger: mix(onDanger, other.onDanger),
    );
  }
}
