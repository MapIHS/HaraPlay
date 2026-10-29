import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/theme/hara_tokens.dart';
import 'package:haraplay/core/widgets/hara_button.dart';
import 'package:haraplay/core/widgets/hara_pressable.dart';

import '../../helpers/test_app.dart';

Offset faceOffset(WidgetTester tester) {
  final transform = tester.widget<Transform>(find.byKey(HaraPressable.faceKey));
  final translation = transform.transform.getTranslation();
  return Offset(translation.x, translation.y);
}

void main() {
  testWidgets('calls onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpHara(
      Center(
        child: HaraButton(label: 'Play', onPressed: () => taps++),
      ),
    );

    await tester.tap(find.text('Play'));
    expect(taps, 1);
  });

  testWidgets('presses in onto its shadow while held, then springs back', (
    tester,
  ) async {
    await tester.pumpHara(
      Center(
        child: HaraButton(label: 'Play', onPressed: () {}),
      ),
    );
    expect(faceOffset(tester), Offset.zero);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Play')),
    );
    await tester.pumpAndSettle();
    expect(
      faceOffset(tester),
      const Offset(HaraShadow.offset, HaraShadow.offset),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(faceOffset(tester), Offset.zero);
  });

  testWidgets('disabled button ignores taps and reports disabled semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpHara(
      const Center(child: HaraButton(label: 'Play', onPressed: null)),
    );

    await tester.tap(find.text('Play'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(faceOffset(tester), Offset.zero);
    expect(
      tester.getSemantics(find.byType(HaraPressable)),
      isSemantics(
        label: 'Play',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });
}
