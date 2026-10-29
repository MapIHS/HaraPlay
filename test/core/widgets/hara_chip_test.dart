import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/widgets/hara_chip.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('stat chip shows the value and an uppercase label', (
    tester,
  ) async {
    await tester.pumpHara(
      const Center(
        child: HaraChip(value: '2020', label: 'Year'),
      ),
    );

    expect(find.text('2020'), findsOneWidget);
    expect(find.text('YEAR'), findsOneWidget);
  });

  testWidgets('announces value and label together', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpHara(
      const Center(
        child: HaraChip(value: '12', label: 'Tracks'),
      ),
    );

    expect(find.bySemanticsLabel('12 Tracks'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('is tappable only when onPressed is set', (tester) async {
    var taps = 0;
    await tester.pumpHara(
      Center(
        child: HaraChip(label: 'Rock', onPressed: () => taps++),
      ),
    );

    await tester.tap(find.text('ROCK'));
    expect(taps, 1);
  });
}
