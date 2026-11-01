import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/theme/hara_colors.dart';
import 'package:haraplay/core/theme/hara_theme.dart';
import 'package:haraplay/core/theme/palettes.dart';
import 'package:haraplay/core/theme/system_tones.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  // Material 3's baseline tonal palettes, as a stand-in for a wallpaper.
  final baseline = SystemTones.fromMap({
    'accent1_200': 0xFFD0BCFF,
    'accent1_600': 0xFF6750A4,
    'neutral1_10': 0xFFFFFBFE,
    'neutral1_50': 0xFFF4EFF4,
    'neutral1_800': 0xFF313033,
    'neutral1_900': 0xFF1C1B1F,
    'neutral2_50': 0xFFF5EEFA,
    'neutral2_100': 0xFFE7E0EC,
    'neutral2_200': 0xFFCAC4D0,
    'neutral2_400': 0xFF938F99,
    'neutral2_600': 0xFF605D66,
  })!;
  final palettes = {
    'saffron light': HaraPalettes.saffronLight,
    'saffron dark': HaraPalettes.saffronDark,
    'periwinkle light': HaraPalettes.periwinkleLight,
    'periwinkle dark': HaraPalettes.periwinkleDark,
    'apricot light': HaraPalettes.apricotLight,
    'apricot dark': HaraPalettes.apricotDark,
    'wallpaper light': HaraPalettes.fromSystem(baseline, Brightness.light),
    'wallpaper dark': HaraPalettes.fromSystem(baseline, Brightness.dark),
  };

  for (final MapEntry(key: name, value: HaraColors c) in palettes.entries) {
    group('$name meets WCAG contrast', () {
      test('text on background and surface ≥ 7:1 (AAA)', () {
        expect(contrast(c.foreground, c.background), greaterThanOrEqualTo(7));
        expect(contrast(c.foreground, c.surface), greaterThanOrEqualTo(7));
      });

      test('muted text on background, surface and surfaceAlt ≥ 4.5:1', () {
        for (final bg in [c.background, c.surface, c.surfaceAlt]) {
          expect(contrast(c.mutedForeground, bg), greaterThanOrEqualTo(4.5));
        }
      });

      test('text on primary fill ≥ 7:1', () {
        expect(contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(7));
      });

      test('emphasis strokes on background and surface ≥ 4.5:1', () {
        expect(contrast(c.emphasis, c.background), greaterThanOrEqualTo(4.5));
        expect(contrast(c.emphasis, c.surface), greaterThanOrEqualTo(4.5));
      });

      test('outline on background ≥ 3:1 (non-text)', () {
        expect(contrast(c.border, c.background), greaterThanOrEqualTo(3));
      });

      test('text on every accent ≥ 4.5:1', () {
        for (final accent in c.accents) {
          expect(contrast(c.foreground, accent), greaterThanOrEqualTo(4.5));
        }
      });

      test('snackbar text and action on the snackbar ≥ 4.5:1', () {
        // The snackbar is drawn in foreground with background-coloured text.
        expect(contrast(c.background, c.foreground), greaterThanOrEqualTo(4.5));
        expect(
          contrast(snackBarActionColor(c), c.foreground),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('danger on background and onDanger on danger ≥ 4.5:1', () {
        expect(contrast(c.danger, c.background), greaterThanOrEqualTo(4.5));
        expect(contrast(c.onDanger, c.danger), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('Wallpaper falls back to Saffron without system colours', () {
    expect(HaraPalettes.of(ColorChoice.wallpaper, null), (
      HaraPalettes.saffronLight,
      HaraPalettes.saffronDark,
    ));
    expect(
      HaraPalettes.of(ColorChoice.wallpaper, baseline).$1.primary,
      const Color(0xFFD0BCFF),
    );
  });

  test('system tones need every key', () {
    expect(SystemTones.fromMap({'accent1_200': 1}), isNull);
    expect(SystemTones.fromMap(null), isNull);
  });
}
