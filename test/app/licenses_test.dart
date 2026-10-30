import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled fonts and icons appear on the licenses page', () async {
    registerAssetLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((e) => e.packages).toSet();

    expect(
      packages,
      containsAll(['Bricolage Grotesque', 'DM Sans', 'Space Mono', 'Lucide']),
    );
    final lucide = entries.firstWhere((e) => e.packages.contains('Lucide'));
    final text = lucide.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('ISC License'));
  });
}
