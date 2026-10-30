import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';

void main() {
  group('mergeTags', () {
    test('fills missing values from the file', () {
      final merged = mergeTags(
        const SongTags(title: 'Saffron Sunset', genre: 'Electronic'),
        const SongTags(
          title: 'Saffron Sunset',
          year: 2024,
          trackNumber: 3,
          discNumber: 1,
          albumArtist: 'The Test Tones',
          genre: 'Ambient',
        ),
      );
      expect(merged.year, 2024);
      expect(merged.trackNumber, 3);
      expect(merged.discNumber, 1);
      expect(merged.albumArtist, 'The Test Tones');
      // MediaStore's own value wins.
      expect(merged.genre, 'Electronic');
    });

    test('fixes text that differs only in accented letters', () {
      final merged = mergeTags(
        const SongTags(title: 'Seńorita Café', artist: 'Beyoncé'),
        const SongTags(title: 'Señorita Café', artist: 'Beyoncé'),
      );
      expect(merged.title, 'Señorita Café');
      expect(merged.artist, 'Beyoncé');
    });

    test('keeps MediaStore text for any other difference', () {
      final merged = mergeTags(
        const SongTags(title: 'Night Drive', album: 'HaraPlay Samples'),
        const SongTags(title: 'Night Drive (Remix)', album: null),
      );
      expect(merged.title, 'Night Drive');
      expect(merged.album, 'HaraPlay Samples');
    });

    test(
      'an ASCII-only difference of the same length is not an encoding fix',
      () {
        expect(isEncodingVariant('Track A', 'Track B'), isFalse);
        expect(isEncodingVariant('Seńorita', 'Señorita'), isTrue);
        expect(isEncodingVariant('same', 'same'), isFalse);
        expect(isEncodingVariant('Cafe', 'Café'), isFalse);
      },
    );
  });

  group('needsFileTags', () {
    const complete = SongTags(
      title: 'Saffron Sunrise',
      artist: 'The Test Tones',
      genre: 'Electronic',
      trackNumber: 1,
      year: 2024,
    );

    test('complete ASCII tags do not need a read', () {
      expect(needsFileTags(complete), isFalse);
    });

    test('a missing album artist alone does not trigger a read', () {
      expect(complete.albumArtist, isNull);
      expect(needsFileTags(complete), isFalse);
    });

    test('missing year, genre or track, or non-ASCII text, does', () {
      expect(
        needsFileTags(const SongTags(title: 'x', genre: 'g', trackNumber: 1)),
        isTrue,
      );
      expect(
        needsFileTags(
          const SongTags(title: 'Café', genre: 'g', trackNumber: 1, year: 1),
        ),
        isTrue,
      );
    });
  });
}
