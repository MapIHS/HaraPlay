import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/router.dart';
import 'package:haraplay/app/shell/bottom_nav.dart';
import 'package:haraplay/features/onboarding/data/media_permission_service.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  group('onboardingRedirect', () {
    String? redirect(MediaAccess access, bool completed, String location) =>
        onboardingRedirect(
          access: access,
          completed: completed,
          location: location,
        );

    test('sends users without access to onboarding', () {
      expect(redirect(MediaAccess.denied, true, '/home'), '/onboarding');
      expect(
        redirect(MediaAccess.permanentlyDenied, false, '/library'),
        '/onboarding',
      );
      expect(redirect(MediaAccess.denied, false, '/onboarding'), isNull);
    });

    test('keeps users on onboarding until the first scan is done', () {
      expect(redirect(MediaAccess.granted, false, '/home'), '/onboarding');
      expect(redirect(MediaAccess.granted, false, '/onboarding'), isNull);
    });

    test('leaves onboarding once access is granted and onboarded', () {
      expect(redirect(MediaAccess.granted, true, '/onboarding'), '/home');
      expect(redirect(MediaAccess.granted, true, '/settings'), isNull);
    });
  });

  testWidgets('first run: allow → scan result → Home', (tester) async {
    final permissions = FakeMediaPermissionService();
    await pumpHaraApp(
      tester,
      prefs: const {},
      initialAccess: MediaAccess.denied,
      permissions: permissions,
      mediaSource: FakeMediaSource([
        testSong(1, albumId: 10),
        testSong(2, albumId: 10),
        testSong(3, albumId: 11, folder: '/storage/emulated/0/Download'),
      ]),
    );

    expect(find.text("Let's find your music"), findsOneWidget);
    expect(find.byType(HaraBottomNav), findsNothing);

    await tester.tap(find.text('Allow access to music'));
    await tester.pumpAndSettle();

    expect(permissions.requestCount, 1);
    expect(find.text('Found 3 songs'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2)); // 2 albums, 2 folders

    expect(permissions.notificationRequestCount, 0);
    await tester.tap(find.text('Start listening'));
    await tester.pumpAndSettle();

    expect(permissions.notificationRequestCount, 1);
    expect(find.text('Shuffle all'), findsOneWidget); // Home, with music
    expect(find.byType(HaraBottomNav), findsOneWidget);
  });

  testWidgets('denied, then permanently denied → open settings', (
    tester,
  ) async {
    final permissions = FakeMediaPermissionService(
      requestResults: [MediaAccess.denied, MediaAccess.permanentlyDenied],
    );
    await pumpHaraApp(
      tester,
      prefs: const {},
      initialAccess: MediaAccess.denied,
      permissions: permissions,
    );

    await tester.tap(find.text('Allow access to music'));
    await tester.pumpAndSettle();
    expect(find.textContaining("can't show your songs"), findsOneWidget);

    await tester.tap(find.text('Allow access to music'));
    await tester.pumpAndSettle();
    expect(find.text('Music access is off'), findsOneWidget);
    expect(find.textContaining('then Music and audio'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(permissions.openSettingsCount, 1);
  });

  testWidgets('a grant made in settings is picked up on resume', (
    tester,
  ) async {
    final permissions = FakeMediaPermissionService(
      requestResults: [MediaAccess.permanentlyDenied],
    );
    await pumpHaraApp(
      tester,
      prefs: const {},
      initialAccess: MediaAccess.denied,
      permissions: permissions,
      mediaSource: FakeMediaSource([testSong(1)]),
    );
    await tester.tap(find.text('Allow access to music'));
    await tester.pumpAndSettle();
    expect(find.text('Music access is off'), findsOneWidget);

    // Still denied when the user comes back without changing anything.
    permissions.status = MediaAccess.denied;
    await _resume(tester);
    expect(find.text('Music access is off'), findsOneWidget);

    permissions.status = MediaAccess.granted;
    await _resume(tester);
    expect(find.text('Found 1 song'), findsOneWidget);
    expect(find.text('FOLDER'), findsOneWidget);
  });

  for (final (sdkInt, steps) in [
    (28, 'tap Permissions and turn on Storage'),
    (31, 'then Files and media, and choose Allow'),
  ]) {
    testWidgets('API $sdkInt explains the right settings steps', (
      tester,
    ) async {
      await pumpHaraApp(
        tester,
        prefs: const {},
        sdkInt: sdkInt,
        initialAccess: MediaAccess.denied,
        permissions: FakeMediaPermissionService(
          requestResults: [MediaAccess.permanentlyDenied],
        ),
      );
      await tester.tap(find.text('Allow access to music'));
      await tester.pumpAndSettle();
      expect(find.textContaining(steps), findsOneWidget);
    });
  }

  testWidgets('an empty library offers a rescan', (tester) async {
    final source = FakeMediaSource();
    await pumpHaraApp(tester, prefs: const {}, mediaSource: source);
    expect(find.text('No music found yet'), findsOneWidget);

    source.songs = [testSong(1), testSong(2)];
    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    expect(find.text('Found 2 songs'), findsOneWidget);
  });

  testWidgets('returning users with access skip onboarding', (tester) async {
    await pumpHaraApp(tester);
    expect(find.text('Welcome to HaraPlay'), findsOneWidget);
  });

  testWidgets('revoked access sends returning users back to the gate', (
    tester,
  ) async {
    await pumpHaraApp(tester, initialAccess: MediaAccess.denied);
    expect(find.text("Let's find your music"), findsOneWidget);

    await tester.tap(find.text('Allow access to music'));
    await tester.pumpAndSettle();
    // Already onboarded, so access alone is enough to continue.
    expect(find.text('Welcome to HaraPlay'), findsOneWidget);
  });
}

/// Simulates leaving for system settings and coming back.
Future<void> _resume(WidgetTester tester) async {
  tester.binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
    ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}
