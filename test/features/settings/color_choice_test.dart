import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/storage/preferences.dart';
import 'package:haraplay/core/theme/hara_colors.dart';
import 'package:haraplay/core/theme/palettes.dart';
import 'package:haraplay/core/theme/system_tones.dart';
import 'package:haraplay/features/settings/presentation/color_choice_controller.dart';

import '../../helpers/test_app.dart';

SystemTones _tones(int accent) => SystemTones.fromMap({
  for (final key in SystemTones.keys) key: 0xFF808080,
  'accent1_200': accent,
})!;

class _FakeTonesChannel implements SystemTonesChannel {
  SystemTones? next;

  @override
  Future<SystemTones?> read() async => next;
}

void main() {
  Color primaryOf(WidgetTester tester) =>
      HaraColors.of(tester.element(find.text('Settings').first)).primary;

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('picking a palette recolours the app and is remembered', (
    tester,
  ) async {
    await pumpHaraApp(tester);
    await openSettings(tester);
    expect(primaryOf(tester), HaraPalettes.saffronLight.primary);
    expect(find.text('Wallpaper'), findsNothing, reason: 'before Android 12');

    await tester.tap(find.bySemanticsLabel('Periwinkle colours'));
    await tester.pumpAndSettle();
    expect(primaryOf(tester), HaraPalettes.periwinkleLight.primary);
    final prefs = ProviderScope.containerOf(
      tester.element(find.text('Settings').first),
    ).read(sharedPreferencesProvider);
    expect(prefs.getString('settings.colorChoice'), 'periwinkle');
  });

  testWidgets('Wallpaper appears with system colours and uses them', (
    tester,
  ) async {
    await pumpHaraApp(tester, systemTones: _tones(0xFF77AADD));
    await openSettings(tester);
    await tester.tap(find.bySemanticsLabel('Wallpaper colours'));
    await tester.pumpAndSettle();
    expect(primaryOf(tester), const Color(0xFF77AADD));
  });

  test('a new wallpaper is picked up on refresh', () async {
    final channel = _FakeTonesChannel();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await createTestPreferences({'settings.colorChoice': 'wallpaper'}),
        ),
        initialSystemTonesProvider.overrideWithValue(_tones(0xFF112233)),
        systemTonesChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(colorChoiceProvider), ColorChoice.wallpaper);

    channel.next = _tones(0xFF445566);
    await container.read(systemTonesProvider.notifier).refresh();
    expect(
      container.read(systemTonesProvider)!.accent1_200,
      const Color(0xFF445566),
    );

    // A failed read keeps the last colours.
    channel.next = null;
    await container.read(systemTonesProvider.notifier).refresh();
    expect(container.read(systemTonesProvider), isNotNull);
  });
}
