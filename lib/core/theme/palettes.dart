import 'dart:ui' show Brightness, Color;

import 'hara_colors.dart';

/// HaraPlay's brand palettes. Saffron is the default (see docs/PLAN.md §2).
abstract final class HaraPalettes {
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
}
