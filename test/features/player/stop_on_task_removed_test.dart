import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/player/presentation/stop_on_task_removed.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('Settings: "Stop when removed from Recent apps"', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    final player = FakePlayer();
    await pumpHaraApp(tester, player: player);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Stop when removed from Recent apps'),
      200,
    );
    expect(
      find.text('Music keeps playing; a paused player always closes'),
      findsOneWidget,
    );
    await tester.tap(find.text('Stop when removed from Recent apps'));
    await tester.pumpAndSettle();
    expect(player.stopOnTaskRemoved, isTrue);
    expect(find.text('Swiping HaraPlay away stops the music'), findsOneWidget);
    final prefs = await createTestPreferences();
    expect(loadStopOnTaskRemoved(prefs), isFalse, reason: 'off by default');
  });
}
