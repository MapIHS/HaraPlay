import 'dart:ui' show Brightness, Color;

import 'hara_colors.dart';
import 'system_tones.dart';

/// The colour choices in Settings › Appearance.
enum ColorChoice {
  saffron('Saffron'),
  periwinkle('Periwinkle'),
  apricot('Apricot'),

  /// Material You colours from the wallpaper (Android 12+).
  wallpaper('Wallpaper');

  const ColorChoice(this.label);

  final String label;
}

/// HaraPlay's brand palettes. Saffron is the default; Periwinkle and
/// Apricot are the other two brand options from docs/PLAN.md §2. The
/// pastel accents and danger colours are shared.
abstract final class HaraPalettes {
  /// Light and dark palettes for [choice]. [tones] are the system's
  /// wallpaper colours; without them "Wallpaper" falls back to Saffron.
  static (HaraColors, HaraColors) of(ColorChoice choice, SystemTones? tones) =>
      switch (choice) {
        ColorChoice.saffron => (saffronLight, saffronDark),
        ColorChoice.periwinkle => (periwinkleLight, periwinkleDark),
        ColorChoice.apricot => (apricotLight, apricotDark),
        ColorChoice.wallpaper when tones != null => (
          fromSystem(tones, Brightness.light),
          fromSystem(tones, Brightness.dark),
        ),
        ColorChoice.wallpaper => (saffronLight, saffronDark),
      };

  static const saffronLight = HaraColors(
    brightness: Brightness.light,
    background: Color(0xFFFBF5E6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3EAD2),
    primary: Color(0xFFFFC738),
    onPrimary: Color(0xFF16130C),
    emphasis: Color(0xFF8A5A00),
    foreground: Color(0xFF16130C),
    mutedForeground: Color(0xFF5E5646),
    border: Color(0xFF16130C),
    shadow: Color(0xFF16130C),
    overlay: Color(0x6616130C),
    mint: Color(0xFFBDEBCF),
    sky: Color(0xFFBCD9FF),
    lilac: Color(0xFFDCCFFF),
    coral: Color(0xFFFFC2B3),
    danger: Color(0xFFB42318),
    onDanger: Color(0xFFFFFFFF),
  );

  static const saffronDark = HaraColors(
    brightness: Brightness.dark,
    background: Color(0xFF16140F),
    surface: Color(0xFF221F17),
    surfaceAlt: Color(0xFF2C281E),
    primary: Color(0xFFF0BA3C),
    onPrimary: Color(0xFF16140F),
    emphasis: Color(0xFFF0BA3C),
    foreground: Color(0xFFF4EEDD),
    mutedForeground: Color(0xFFB9B09A),
    border: Color(0xFF8C7E5A),
    shadow: Color(0xFF8C7E5A),
    overlay: Color(0x99000000),
    mint: Color(0xFF2F5A43),
    sky: Color(0xFF2F4B6E),
    lilac: Color(0xFF4A3D73),
    coral: Color(0xFF6E3A2F),
    danger: Color(0xFFFF7A72),
    onDanger: Color(0xFF16140F),
  );

  static final periwinkleLight = saffronLight.copyWith(
    background: const Color(0xFFF2F3FC),
    surfaceAlt: const Color(0xFFE4E7FA),
    primary: const Color(0xFF9DABFF),
    onPrimary: const Color(0xFF11131F),
    emphasis: const Color(0xFF3F4DB0),
    foreground: const Color(0xFF11131F),
    mutedForeground: const Color(0xFF4E5370),
    border: const Color(0xFF11131F),
    shadow: const Color(0xFF11131F),
    overlay: const Color(0x6611131F),
  );

  static final periwinkleDark = saffronDark.copyWith(
    background: const Color(0xFF12131C),
    surface: const Color(0xFF1C1E2B),
    surfaceAlt: const Color(0xFF262938),
    primary: const Color(0xFF8F9CF4),
    onPrimary: const Color(0xFF12131C),
    emphasis: const Color(0xFF8F9CF4),
    foreground: const Color(0xFFECEEFB),
    mutedForeground: const Color(0xFFAEB3D3),
    border: const Color(0xFF7C84BC),
    shadow: const Color(0xFF7C84BC),
    onDanger: const Color(0xFF12131C),
  );

  static final apricotLight = saffronLight.copyWith(
    background: const Color(0xFFFDF3EC),
    surfaceAlt: const Color(0xFFF8E3D6),
    primary: const Color(0xFFFFB48C),
    onPrimary: const Color(0xFF1A120E),
    emphasis: const Color(0xFFA0461A),
    foreground: const Color(0xFF1A120E),
    mutedForeground: const Color(0xFF64524A),
    border: const Color(0xFF1A120E),
    shadow: const Color(0xFF1A120E),
    overlay: const Color(0x661A120E),
  );

  static final apricotDark = saffronDark.copyWith(
    background: const Color(0xFF18120F),
    surface: const Color(0xFF241B16),
    surfaceAlt: const Color(0xFF2E231D),
    primary: const Color(0xFFEFA47E),
    onPrimary: const Color(0xFF18120F),
    emphasis: const Color(0xFFEFA47E),
    foreground: const Color(0xFFF7ECE6),
    mutedForeground: const Color(0xFFC2AEA4),
    border: const Color(0xFFA07C69),
    shadow: const Color(0xFFA07C69),
    onDanger: const Color(0xFF18120F),
  );

  /// The wallpaper's tonal palettes mapped onto HaraPlay's roles. The look
  /// stays HaraPlay's own: near-black outlines and hard shadows in light
  /// mode, the accent tone 80 as the fill (dark text on it), tone 40 for
  /// thin lines on light pages.
  static HaraColors fromSystem(SystemTones t, Brightness brightness) {
    if (brightness == Brightness.light) {
      return saffronLight.copyWith(
        background: t.neutral2_50,
        surface: t.neutral1_10,
        surfaceAlt: t.neutral2_100,
        primary: t.accent1_200,
        onPrimary: t.neutral1_900,
        emphasis: t.accent1_600,
        foreground: t.neutral1_900,
        mutedForeground: t.neutral2_600,
        border: t.neutral1_900,
        shadow: t.neutral1_900,
        overlay: t.neutral1_900.withAlpha(0x66),
      );
    }
    return saffronDark.copyWith(
      background: t.neutral1_900,
      surface: Color.lerp(t.neutral1_900, t.neutral1_800, 0.5),
      surfaceAlt: t.neutral1_800,
      primary: t.accent1_200,
      onPrimary: t.neutral1_900,
      emphasis: t.accent1_200,
      foreground: t.neutral1_50,
      mutedForeground: t.neutral2_200,
      border: t.neutral2_400,
      shadow: t.neutral2_400,
      onDanger: t.neutral1_900,
    );
  }
}
