import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide key/value preferences (synchronous reads, async writes).
///
/// Created in `bootstrap()` and injected via a [ProviderScope] override.
final sharedPreferencesProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap()',
  ),
);

Future<SharedPreferencesWithCache> createPreferences() {
  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
}
