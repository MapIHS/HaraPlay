import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/features/library/data/filename_tags.dart';
import 'package:haraplay/features/library/data/tag_merge.dart';

void main() {
  group('inferFromFileName', () {
    void expectParsed(String stem, String artist, String title) {
      final parsed = inferFromFileName(stem);
      expect(parsed, isNotNull, reason: stem);
      expect((parsed!.artist, parsed.title), (artist, title), reason: stem);
    }

    test('Artist - Title', () {
      expectParsed('Mono Lisa - Night Drive', 'Mono Lisa', 'Night Drive');
      expectParsed(
        'Some Artist - A Song (Feat. Guest) [Official Video]',
        'Some Artist',
        'A Song (Feat. Guest)',
      );
    });

    test('other dashes and extra spaces', () {
      expectParsed('Kai Tone – Opus', 'Kai Tone', 'Opus');
      expectParsed('Kai Tone —  Opus', 'Kai Tone', 'Opus');
      expectParsed(
        'Remixer -  Is It Me_ __ Singer (Lyrics)',
        'Remixer',
        'Is It Me_ __ Singer',
      );
    });

    test('leading track numbers are stripped', () {
      expectParsed('01 - Mono Lisa - Night Drive', 'Mono Lisa', 'Night Drive');
      expectParsed('01. Mono Lisa - Night Drive', 'Mono Lisa', 'Night Drive');
      expectParsed('3) Mono Lisa - Night Drive', 'Mono Lisa', 'Night Drive');
      expectParsed('07 Mono Lisa - Night Drive', 'Mono Lisa', 'Night Drive');
    });

    test('numbers that are part of the artist are kept', () {
      expectParsed('50 Cent - In Da Club', '50 Cent', 'In Da Club');
      expectParsed('2Pac - Changes', '2Pac', 'Changes');
    });

    test('accented and non-Latin names', () {
      expectParsed('Beyoncé - Halo', 'Beyoncé', 'Halo');
      expectParsed('ユイカ - 好きだから', 'ユイカ', '好きだから');
    });

    test('a final bracket-only part joins the title', () {
      expectParsed('Remixer - Paralyzed - (Lyrics)', 'Remixer', 'Paralyzed');
      expectParsed('Remixer - Song - (Live)', 'Remixer', 'Song (Live)');
      expectParsed(
        'Remixer - Song - [Remix] - (HD)',
        'Remixer',
        'Song [Remix]',
      );
    });

    test('download noise is stripped, other brackets kept', () {
      for (final noise in [
        '(Lyrics)',
        '(lyrics)',
        '(Lyric Video)',
        '(Official Video)',
        '(OFFICIAL MUSIC VIDEO)',
        '(Official Audio)',
        '(Audio)',
        '(HD)',
        '(HQ)',
        '[Lyrics]',
        '[Official Music Video]',
        '[hd]',
        '( Lyrics )',
      ]) {
        expectParsed(
          'Mono Lisa - Night Drive $noise',
          'Mono Lisa',
          'Night Drive',
        );
      }
      expectParsed(
        'Mono Lisa - Night Drive (Remix) (Lyrics) [HD]',
        'Mono Lisa',
        'Night Drive (Remix)',
      );
      expectParsed(
        'Mono Lisa - Night Drive (feat. Kai)',
        'Mono Lisa',
        'Night Drive (feat. Kai)',
      );
      expectParsed(
        'Mono Lisa - Night Drive (Live)',
        'Mono Lisa',
        'Night Drive (Live)',
      );
      // Noise in the middle stays: only the end is cleaned.
      expectParsed(
        'Mono Lisa - (Lyrics) Night Drive',
        'Mono Lisa',
        '(Lyrics) Night Drive',
      );
      // A title that is only noise is kept rather than emptied.
      expectParsed(
        'Mono Lisa - (Official Video)',
        'Mono Lisa',
        '(Official Video)',
      );
    });

    test('ambiguous or implausible names are left alone', () {
      for (final stem in [
        'Night Drive', // no separator
        'Remixer  Umbrella Lyrics', // no dash
        'Artist-Title', // unspaced dash: often part of a word
        'A - B - C',
        'A - B - C (Lyrics)', // last part is not only a bracket
        'y2mate.com - Some Song', // website, not an artist
        'www.example.net - Some Song',
        '01 - Night Drive', // track number and title only
        '1234 - Night Drive', // artist without letters
        ' - Night Drive',
        'Mono Lisa - ',
        '${'x' * 61} - Night Drive',
      ]) {
        expect(inferFromFileName(stem), isNull, reason: stem);
      }
    });
  });

  group('withFilenameTags', () {
    const path = '/storage/emulated/0/Music/Mono Lisa - Night Drive.mp3';

    test('applies when there is no artist and the title is the file name', () {
      final (tags, inferred) = withFilenameTags(
        const SongTags(title: 'Mono Lisa - Night Drive', year: 2019),
        path,
      );
      expect(inferred, isTrue);
      expect(tags.artist, 'Mono Lisa');
      expect(tags.title, 'Night Drive');
      expect(tags.year, 2019);
    });

    test('never overwrites a real artist tag', () {
      final (tags, inferred) = withFilenameTags(
        const SongTags(title: 'Mono Lisa - Night Drive', artist: 'Tagged'),
        path,
      );
      expect(inferred, isFalse);
      expect(tags.artist, 'Tagged');
    });

    test('real tags keep their download noise', () {
      final (tags, inferred) = withFilenameTags(
        const SongTags(title: 'Night Drive (Official Video)', artist: 'Tag'),
        path,
      );
      expect(inferred, isFalse);
      expect(tags.title, 'Night Drive (Official Video)');
    });

    test('never overwrites a real title tag', () {
      final (tags, inferred) = withFilenameTags(
        const SongTags(title: 'Real Title'),
        path,
      );
      expect(inferred, isFalse);
      expect(tags.title, 'Real Title');
    });

    test('fileStem', () {
      expect(fileStem('/a/b/01. Song.name.flac'), '01. Song.name');
      expect(fileStem('/a/.hidden'), '.hidden');
    });
  });
}
