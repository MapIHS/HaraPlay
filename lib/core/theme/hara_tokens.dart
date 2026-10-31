import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 4-pt spacing scale.
abstract final class HaraSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter.
  static const double gutter = lg;
}

abstract final class HaraRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;
}

abstract final class HaraBorder {
  /// List rows, inputs, chips.
  static const double thin = 1.5;

  /// Cards, buttons, artwork.
  static const double regular = 2;
}

/// Hard (zero-blur) offset shadows — the core of the neo-brutalist look.
abstract final class HaraShadow {
  static const double offset = 3;
  static const double small = 2;
}

abstract final class HaraMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  /// Emphasised easing for most transitions.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve accelerate = Curves.easeInCubic;
}

abstract final class HaraSizes {
  static const double minTouchTarget = 48;
  static const double iconSmall = 20;
  static const double icon = 24;
  static const double iconTransport = 32;
  static const double songTileHeight = 64;

  /// One text line of [fontSize] / [lineHeight] at the user's text size.
  static double _line(TextScaler scaler, double fontSize, double lineHeight) =>
      scaler.scale(fontSize) * lineHeight / fontSize;

  /// A two-line row (song, browse and queue rows): [songTileHeight] at the
  /// default text size, taller when the user enlarges text.
  static double rowHeightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(
      songTileHeight,
      _line(scaler, 16, 20) + 2 + _line(scaler, 13, 18) + 24,
    );
  }

  /// The title and subtitle under a card's artwork (album and song cards).
  static double cardLabelHeightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(
      52,
      HaraSpacing.sm + _line(scaler, 14, 18) + _line(scaler, 13, 18) + 6,
    );
  }

  static const double songTileArtwork = 48;
}
