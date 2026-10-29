import 'package:flutter/material.dart';

import 'hara_colors.dart';

abstract final class HaraFonts {
  static const display = 'BricolageGrotesque';
  static const body = 'DMSans';
  static const mono = 'SpaceMono';
}

/// Builds text styles for HaraPlay.
///
/// Bricolage Grotesque and DM Sans are variable fonts, so every style sets
/// both [TextStyle.fontWeight] and the matching `wght` (and `opsz`) font
/// variations — otherwise Android renders the font's default instance.
abstract final class HaraTypography {
  static TextTheme textTheme(HaraColors colors) {
    final fg = colors.foreground;
    final muted = colors.mutedForeground;
    return TextTheme(
      displaySmall: _display(34, 38, FontWeight.w800, fg),
      headlineMedium: _display(26, 30, FontWeight.w800, fg),
      headlineSmall: _display(22, 26, FontWeight.w800, fg),
      titleLarge: _display(20, 24, FontWeight.w700, fg),
      titleMedium: _body(16, 20, FontWeight.w700, fg),
      titleSmall: _body(14, 18, FontWeight.w700, fg),
      bodyLarge: _body(16, 22, FontWeight.w400, fg),
      bodyMedium: _body(15, 20, FontWeight.w400, fg),
      bodySmall: _body(13, 18, FontWeight.w400, muted),
      labelLarge: _body(15, 20, FontWeight.w700, fg),
      labelMedium: _body(12, 16, FontWeight.w600, fg, letterSpacing: 0.4),
      labelSmall: _body(11, 14, FontWeight.w600, muted, letterSpacing: 0.4),
    );
  }

  static HaraTextStyles extras(HaraColors colors) => HaraTextStyles(
    mono: _mono(12, 16, FontWeight.w400, colors.mutedForeground),
    monoStrong: _mono(13, 16, FontWeight.w700, colors.foreground),
  );

  /// Returns [style] at [weight], keeping the variable-font axis in sync.
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    final others = (style.fontVariations ?? const <FontVariation>[]).where(
      (v) => v.axis != 'wght',
    );
    return style.copyWith(
      fontWeight: weight,
      fontVariations: [
        ...others,
        FontVariation.weight(weight.value.toDouble()),
      ],
    );
  }

  static TextStyle _display(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color,
  ) => _variable(
    HaraFonts.display,
    size,
    lineHeight,
    weight,
    color,
    opticalSize: size.clamp(12, 96).toDouble(),
    letterSpacing: -0.2,
  );

  static TextStyle _body(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color, {
    double letterSpacing = 0,
  }) => _variable(
    HaraFonts.body,
    size,
    lineHeight,
    weight,
    color,
    opticalSize: size.clamp(9, 40).toDouble(),
    letterSpacing: letterSpacing,
  );

  static TextStyle _variable(
    String family,
    double size,
    double lineHeight,
    FontWeight weight,
    Color color, {
    required double opticalSize,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      fontVariations: [
        FontVariation.weight(weight.value.toDouble()),
        FontVariation.opticalSize(opticalSize),
      ],
    );
  }

  static TextStyle _mono(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color,
  ) => TextStyle(
    fontFamily: HaraFonts.mono,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Text styles that have no slot in Material's [TextTheme].
@immutable
class HaraTextStyles extends ThemeExtension<HaraTextStyles> {
  const HaraTextStyles({required this.mono, required this.monoStrong});

  /// Times, counters (muted).
  final TextStyle mono;

  /// Emphasised numbers, e.g. the value in a stat chip.
  final TextStyle monoStrong;

  static HaraTextStyles of(BuildContext context) =>
      Theme.of(context).extension<HaraTextStyles>()!;

  @override
  HaraTextStyles copyWith({TextStyle? mono, TextStyle? monoStrong}) =>
      HaraTextStyles(
        mono: mono ?? this.mono,
        monoStrong: monoStrong ?? this.monoStrong,
      );

  @override
  HaraTextStyles lerp(HaraTextStyles? other, double t) {
    if (other == null) return this;
    return HaraTextStyles(
      mono: TextStyle.lerp(mono, other.mono, t)!,
      monoStrong: TextStyle.lerp(monoStrong, other.monoStrong, t)!,
    );
  }
}
