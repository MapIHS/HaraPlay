import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:haraplay/features/settings/presentation/privacy_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('Settings › Privacy shows the policy in the app', (tester) async {
    final view = tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(view.reset);
    await pumpHaraApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Privacy'), 300);
    await tester.ensureVisible(find.text('Privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    expect(find.text('The short version'), findsOneWidget);
    expect(
      find.textContaining('collects no data, shares no data'),
      findsOneWidget,
    );
    expect(find.textContaining('no internet permission'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('automatic cloud backup'),
      300,
      scrollable: find.descendant(
        of: find.byType(PrivacyScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.textContaining('automatic cloud backup is turned off'),
      findsOneWidget,
    );
  });

  test('Android cloud backup is off: allowBackup and the extraction rules', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    final cloud = rules.substring(
      rules.indexOf('<cloud-backup>'),
      rules.indexOf('</cloud-backup>'),
    );
    for (final domain in [
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
    ]) {
      expect(cloud, contains('<exclude domain="$domain" />'));
    }
  });

  test('the in-app policy and PRIVACY.md carry the same date', () {
    final screen = File(
      'lib/features/settings/presentation/privacy_screen.dart',
    ).readAsStringSync();
    final date = RegExp(r"updated = '([^']+)'").firstMatch(screen)![1]!;
    expect(
      File('PRIVACY.md').readAsStringSync(),
      contains('Last updated: $date'),
    );
  });
}
