import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('announces each tab with its selected state', (tester) async {
    final handle = tester.ensureSemantics();
    int? tapped;
    await tester.pumpHara(
      HaraBottomNav(currentIndex: 1, onSelected: (i) => tapped = i),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Library')),
      isSemantics(
        label: 'Library',
        hint: 'Tab 2 of 4',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Home')),
      isSemantics(
        label: 'Home',
        hint: 'Tab 1 of 4',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('Search'));
    expect(tapped, 2);
    handle.dispose();
  });

  testWidgets('every tab keeps a 48dp touch target', (tester) async {
    await tester.pumpHara(HaraBottomNav(currentIndex: 0, onSelected: (_) {}));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(
      tester.getSize(find.byType(HaraBottomNav)).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.byType(InkWell), findsNWidgets(4));
  });
}
