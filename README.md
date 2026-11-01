# HaraPlay

**An offline music player for Android.** HaraPlay plays the music files
already on your phone. No streaming, no account, no ads, no tracking, and
no internet permission at all: nothing leaves your device.

Built with Flutter, with a bold neo-brutalist look (thick outlines, hard
shadows, a saffron accent) in light and dark.

<p>
  <img src="docs/screenshots/home-light.png" width="200" alt="Home, light theme">
  <img src="docs/screenshots/nowplaying-light.png" width="200" alt="Now Playing with a FLAC badge and the wavy seek bar">
  <img src="docs/screenshots/lyrics-light.png" width="200" alt="Synced lyrics">
</p>
<p>
  <img src="docs/screenshots/home-dark.png" width="200" alt="Home, dark theme">
  <img src="docs/screenshots/library-dark.png" width="200" alt="Albums in the library">
  <img src="docs/screenshots/nowplaying-dark.png" width="200" alt="Now Playing, dark theme">
  <img src="docs/screenshots/settings-dark.png" width="200" alt="Settings with colour palettes">
</p>

## Features

**Library**
- Reads your music through Android's MediaStore: songs, albums, artists,
  folders and genres, each with its own sort options.
- Search across titles, artists and albums.
- Home with recently played, most played and recently added.
- Listening stats with charts.
- Fixes up messy tags: reads files' own tags where MediaStore's are missing
  or garbled, and guesses artist and title from file names.
- Hide short audio (ringtones, voice notes), exclude folders, and rescan
  automatically when files change.

**Playback**
- Gapless playback, shuffle and repeat, a reorderable queue.
- Notification and lock-screen controls; pauses when headphones are
  unplugged.
- Optional crossfade (2–12 s); tracks of the same album played in order stay
  gapless.
- Sleep timer with a gentle fade-out, playback speed (0.5–2×, pitch kept).
- Equalizer with presets and a loudness boost, ReplayGain (track or album).
- Swipe the artwork to change songs, double-tap its sides to skip 10 s.

**Your music, your way**
- Likes and playlists; import and export playlists as `.m3u`.
- Lyrics: synced `.lrc` files next to the song, or lyrics embedded in the
  file, with the current line highlighted.
- Audio details: format, bit depth and sample rate (e.g. "FLAC · 24-bit /
  96 kHz"), bitrate.
- Light, dark or system theme; Saffron, Periwinkle and Apricot palettes, or
  your wallpaper's colours on Android 12+.
- "Open with" for audio files from other apps.
- Back up likes, playlists, play history and settings to a file, and restore
  it on a new install or another phone. Restoring adds to what's there and
  never replaces anything.

## Install

1. Download `HaraPlay-<version>.apk` from the
   [latest release](https://github.com/MapIHS/HaraPlay/releases/latest).
   Optionally check it against the `.sha256` file next to it.
2. Open the APK on your phone and allow installing from that source when
   Android asks.
3. Open HaraPlay and allow access to your music.

**Requires Android 7.0 (API 24) or newer.** Updates from the Releases page
install over the previous version and keep your data.

## Build from source

Requirements: Flutter 3.47+ (Dart 3.13+), the Android SDK and JDK 17.

```bash
flutter pub get
flutter analyze
flutter test
flutter run                    # debug build on a connected device
```

The two build types are separate Android apps, so they can be installed
side by side, each with its own data:

| | Release | Debug |
|---|---|---|
| Application ID | `com.mmi.haraplay` | `com.mmi.haraplay.debug` |
| Name / icon | HaraPlay | HaraPlay Dev (dark icon with a DEV badge) |
| Build | `flutter build apk --release` | `flutter build apk --debug` |

### Signing a release build

Release builds are signed with the key described in
`android/key.properties`, which is not part of this repository:

```properties
storeFile=/absolute/path/to/your-release.jks
storePassword=…
keyAlias=…
keyPassword=…
```

Create your own keystore (for example with `keytool -genkeypair -v
-keystore your-release.jks -keyalg RSA -keysize 2048 -validity 10000
-alias haraplay`) and keep it and `key.properties` out of version control
(both are in `.gitignore`). Without `key.properties` the release APK is
built unsigned and won't install. An APK signed with your own key can't
update the official release app (or the other way round); Android requires
uninstalling the other one first.

### Code generation and tools

- The drift database code (`*.g.dart`) is generated and committed. After
  changing a table or DAO, run `dart run build_runner build`.
- `dart run tool/gen_icons.dart` regenerates `HaraIcons` from
  `tool/icons.txt` (Lucide icon names).
- `tool/make_launcher_icons.sh` (and `… dev` for HaraPlay Dev) renders the
  launcher icons from `tool/icon/` (needs ImageMagick with librsvg).
- `tool/make_test_audio.sh` and the other `tool/make_*_audio.sh` scripts
  generate test tones (needs ffmpeg) for gapless, ReplayGain, lyrics and
  large-library checks on an emulator.

## Clean-room note

HaraPlay was written from scratch. Two existing open-source players,
[nuclear](https://github.com/nukeop/nuclear) and
[omniplay](https://github.com/mininxd/omniplay), were studied only as
visual and behavioural references. No code, assets or text from either
project were copied or translated into HaraPlay. The app icon and all
artwork are original.

## License

HaraPlay is released under the [MIT License](LICENSE)
(© 2026 The HaraPlay Authors). The bundled fonts (SIL Open Font License
1.1), the Lucide icon font (ISC) and the libraries built into the app are
listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
