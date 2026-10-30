import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled fonts and icons, with the asset holding each license text.
const _bundledAssetLicenses = <(List<String>, String)>[
  (['Bricolage Grotesque'], 'assets/fonts/bricolage_grotesque/OFL.txt'),
  (['DM Sans'], 'assets/fonts/dm_sans/OFL.txt'),
  (['Space Mono'], 'assets/fonts/space_mono/OFL.txt'),
  (['Lucide'], 'assets/icons/lucide/LICENSE'),
];

/// Adds the bundled asset licenses to the licenses page. Dart package
/// licenses are registered by Flutter automatically.
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (packages, path) in _bundledAssetLicenses) {
      yield LicenseEntryWithLineBreaks(
        packages,
        await rootBundle.loadString(path),
      );
    }
  });
}
