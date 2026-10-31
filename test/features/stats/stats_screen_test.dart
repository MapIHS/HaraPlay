import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/database/app_database.dart';
import 'package:haraplay/features/stats/presentation/stats_charts.dart';
import 'package:haraplay/features/stats/presentation/stats_screen.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
  });

  Future<void> settleDb(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settleDb(tester);
  }

  /// A listen [ago] before now.
  Future<void> listen(
    Duration ago, {
    int song = 1,
    int seconds = 120,
    String? title,
  }) => db.playEventsDao.insertEvent(
    PlayEventsCompanion.insert(
      songId: Value(song),
      songPath: '/storage/emulated/0/Music/song$song.mp3',
      title: title ?? 'Song $song',
      artist: const Value('Kai Tone'),
      album: const Value('Roads'),
      startedAt: clock.now().subtract(ago).millisecondsSinceEpoch,
      listenedMs: seconds * 1000,
      durationMs: 180000,
      completed: false,
      source: PlaySource.songs,
    ),
  );

  /// The visible tab's vertical list.
  Finder list() => find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .hitTestable()
      .first;

  Future<void> openStats(WidgetTester tester) async {
    await tapAndSettle(tester, find.byTooltip('Listening stats'));
    expect(find.byType(StatsScreen), findsOneWidget);
  }

  /// Seeds the database (before the app runs: drift work started inside
  /// the widget test's fake clock never finishes), then opens the app.
  Future<void> library(
    WidgetTester tester, [
    Future<void> Function()? seed,
  ]) async {
    db = createTestDatabase();
    await db.libraryDao.applyScan([mediaSong(1), mediaSong(2)]);
    await seed?.call();
    await pumpHaraApp(tester, database: db);
    await settleDb(tester);
  }

  testWidgets('no history: a friendly empty state on both tabs', (
    tester,
  ) async {
    await library(tester);
    await openStats(tester);
    expect(find.text('Nothing played yet'), findsOneWidget);
    await tapAndSettle(tester, find.text('History'));
    expect(find.text('No history yet'), findsOneWidget);
  });

  testWidgets('stats for a range: totals, charts and top lists', (
    tester,
  ) async {
    await library(tester, () async {
      for (var i = 0; i < 3; i++) {
        await listen(Duration(hours: i + 1), song: 2);
      }
      await listen(const Duration(days: 2));
      await listen(const Duration(days: 3), seconds: 5); // skip
      await listen(const Duration(days: 100)); // outside a month
    });
    await openStats(tester);

    // Month: 4 counted plays of 2 songs; 8 min 5 s listened ≈ 8 min.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('PLAYS'), findsOneWidget);
    expect(find.byType(ListeningClock), findsOneWidget);
    expect(find.byType(WeekdayBars), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Top songs'),
      300,
      scrollable: list(),
    );
    expect(find.text('3 plays'), findsNothing); // shown with the artist
    expect(find.text('Kai Tone · 3 plays'), findsOneWidget);

    // All time includes the old listen.
    await tester.scrollUntilVisible(
      find.text('All time'),
      -300,
      scrollable: list(),
    );
    await tapAndSettle(tester, find.text('All time'));
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('tapping a weekday shows its total', (tester) async {
    await library(tester, () => listen(Duration.zero, seconds: 600));
    await openStats(tester);
    final today = clock.now().weekday - 1;
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    expect(find.text('${names[today]} · 10 min'), findsOneWidget);
    final other = (today + 1) % 7;
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('${names[other]}, No listening'),
      200,
      scrollable: list(),
    );
    await tapAndSettle(
      tester,
      find.bySemanticsLabel('${names[other]}, No listening'),
    );
    expect(find.text('${names[other]} · No listening'), findsOneWidget);
  });

  testWidgets('history: grouped by day, skips marked, pages load', (
    tester,
  ) async {
    await library(tester, () async {
      await listen(const Duration(minutes: 5), seconds: 4, title: 'Newest');
      for (var i = 0; i < 70; i++) {
        await listen(Duration(days: 2, minutes: i), title: 'Old listen $i');
      }
    });
    await openStats(tester);
    await tapAndSettle(tester, find.text('History'));

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.textContaining('Skipped after 0:04'), findsOneWidget);
    expect(find.text('Old listen 69'), findsNothing);

    // Scrolling to the end loads the next page.
    for (
      var i = 0;
      i < 20 && find.text('Old listen 69').evaluate().isEmpty;
      i++
    ) {
      // Drag in the middle of the screen, inside the history list.
      await tester.dragFrom(const Offset(180, 400), const Offset(0, -1500));
      await settleDb(tester);
    }
    expect(find.text('Old listen 69'), findsOneWidget);
  });
}
