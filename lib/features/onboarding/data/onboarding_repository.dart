import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';

/// Remembers whether the first-run flow (permission + first scan) finished.
class OnboardingRepository {
  OnboardingRepository(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _completedKey = 'onboarding.completed';

  bool readCompleted() => _prefs.getBool(_completedKey) ?? false;

  Future<void> writeCompleted() => _prefs.setBool(_completedKey, true);
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(sharedPreferencesProvider)),
);
