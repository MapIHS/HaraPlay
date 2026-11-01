import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/palettes.dart';
import '../../../core/theme/system_tones.dart';
import '../data/settings_repository.dart';

/// The user's colour choice, persisted across launches.
class ColorChoiceController extends Notifier<ColorChoice> {
  @override
  ColorChoice build() =>
      ref.watch(settingsRepositoryProvider).readColorChoice();

  Future<void> set(ColorChoice choice) async {
    if (choice == state) return;
    state = choice;
    await ref.read(settingsRepositoryProvider).writeColorChoice(choice);
  }
}

final colorChoiceProvider =
    NotifierProvider<ColorChoiceController, ColorChoice>(
      ColorChoiceController.new,
    );

final systemTonesChannelProvider = Provider<SystemTonesChannel>(
  (ref) => const SystemTonesChannel(),
);

/// Read in `bootstrap()` so the first frame already has the right colours.
final initialSystemTonesProvider = Provider<SystemTones?>((ref) => null);

/// The wallpaper colours, or null before Android 12. Re-read when the app
/// comes back to the foreground (the wallpaper may have changed).
class SystemTonesController extends Notifier<SystemTones?> {
  @override
  SystemTones? build() => ref.watch(initialSystemTonesProvider);

  Future<void> refresh() async {
    final tones = await ref.read(systemTonesChannelProvider).read();
    if (tones != null && tones != state) state = tones;
  }
}

final systemTonesProvider =
    NotifierProvider<SystemTonesController, SystemTones?>(
      SystemTonesController.new,
    );
