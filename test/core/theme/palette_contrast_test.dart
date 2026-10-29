import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/theme/hara_colors.dart';
import 'package:haraplay/core/theme/palettes.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  const palettes = {
    'saffron light': HaraPalettes.saffronLight,
    'saffron dark': HaraPalettes.saffronDark,
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

      test('danger on background and onDanger on danger ≥ 4.5:1', () {
        expect(contrast(c.danger, c.background), greaterThanOrEqualTo(4.5));
        expect(contrast(c.onDanger, c.danger), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
