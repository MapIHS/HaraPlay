import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/daos/library_dao.dart';
import 'package:haraplay/features/library/presentation/rescan.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('rescan reports what changed', (tester) async {
    final source = FakeMediaSource([mediaSong(1), mediaSong(2)]);
    await pumpHaraApp(tester, mediaSource: source);
    await openSettings(tester);

    await tester.tap(find.text('Rescan library'));
    await tester.pumpAndSettle();
    expect(find.text('2 added. 2 songs in total.'), findsOneWidget);

    source.songs = [mediaSong(2)];
    await tester.tap(find.text('Rescan library'));
    await tester.pumpAndSettle();
    expect(find.text('1 removed. 1 song in total.'), findsOneWidget);
  });

  testWidgets('the minimum length can be changed and persists', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    await pumpHaraApp(tester);
    await openSettings(tester);
    expect(find.text('Hides files shorter than 30 s'), findsOneWidget);

    await tester.tap(find.text('Hide short audio'));
    await tester.pumpAndSettle();
    // The sheet's option, not the ReplayGain tile's "Off".
    await tester.tap(find.text('Off').last);
    await tester.pumpAndSettle();

    expect(find.text('Off: every audio file is shown'), findsOneWidget);
  });

  test('describeSync wording', () {
    const unchanged = SyncResult(
      added: 0,
      updated: 0,
      removed: 0,
      rekeyed: 3,
      total: 1,
    );
    expect(describeSync(unchanged), 'Library is up to date: 1 song.');
    const changed = SyncResult(
      added: 2,
      updated: 1,
      removed: 0,
      rekeyed: 0,
      total: 12,
    );
    expect(describeSync(changed), '2 added, 1 updated. 12 songs in total.');
  });
}
