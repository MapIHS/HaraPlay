import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/core/utils/text_normalize.dart';

void main() {
  test('folds case and Latin diacritics', () {
    expect(foldForSearch('Beyoncé Sinewave'), 'beyonce sinewave');
    expect(foldForSearch('Ünïcode Dreams'), 'unicode dreams');
    expect(foldForSearch('Señorita Café'), 'senorita cafe');
    expect(foldForSearch('Sigur Rós · Æðlarós'), 'sigur ros · aedlaros');
    expect(foldForSearch('Straße Łódź'), 'strasse lodz');
  });

  test('leaves other scripts alone', () {
    expect(foldForSearch('好きだから。'), '好きだから。');
    expect(foldForSearch('Ελλάδα'), 'ελλάδα');
  });

  test('buildSearchText joins non-null parts', () {
    expect(
      buildSearchText(['Night Drive', null, 'Mono Lisa']),
      'night drive mono lisa',
    );
  });

  test('hasNonAscii', () {
    expect(hasNonAscii('plain ascii'), isFalse);
    expect(hasNonAscii('Café'), isTrue);
  });
}
