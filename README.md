# HaraPlay

An offline music player for Android, built with Flutter. Plays the music
already on your device: no streaming, no account, no internet permission.

**Status: 0.1.0, released 2026-11-01.** The MVP (M0–M11), the advanced
milestones (A1–A8) and two follow-ups (B1 backup / restore, B2 debug
build as a separate app) are done. See [`../docs/PLAN.md`](../docs/PLAN.md)
for the plan and how each milestone was built, and
[`../docs/ANALYSIS.md`](../docs/ANALYSIS.md) for the reference analysis.

## Features

- Library from MediaStore: songs, albums, artists, folders, genres; sorts,
  search, Home (recently played, most played, recently added), stats.
- Playback: gapless queue, shuffle / repeat, queue sheet, notification and
  lock screen, sleep timer, playback speed, crossfade (off by default),
  ReplayGain, equalizer and loudness boost, swipe and double-tap gestures,
  a wavy seek bar.
- Likes and playlists, `.m3u` import / export, lyrics (`.lrc` next to the
  song, or embedded), audio format badges.
- Settings: theme (system / light / dark), colour palettes (Saffron,
  Periwinkle, Apricot, and wallpaper colours on Android 12+), excluded
  folders, hide short audio, automatic rescans.
- "Open with" for audio files from other apps.
- Backup / restore of likes, playlists, play history and settings to one
  JSON file (Settings › Your data). Restoring merges and never replaces.

## Requirements

- Flutter 3.47+ (Dart 3.13+), Android SDK, JDK 17
- Android 7.0 (API 24) or newer on the device

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # debug build: "HaraPlay Dev"
```

The drift database code (`*.g.dart`) is generated and committed. After
changing a table or DAO, regenerate it:

```bash
dart run build_runner build
```

## Debug and release builds

The two build types are **separate Android apps**, so they can be
installed side by side:

| | Release | Debug |
|---|---|---|
| Application ID | `com.mmi.haraplay` | `com.mmi.haraplay.debug` |
| Name / icon | HaraPlay, saffron icon | HaraPlay Dev, dark icon with a DEV badge |
| Version name | from `pubspec.yaml` (e.g. `0.1.0`) | the same plus `-dev` |
| Signed with | the HaraPlay release key | the local Android debug key |

Because they are different packages, each has its own data: library
database, likes, playlists, play history, settings, queue, permission
grants and notifications. Both read the same music files. Data moves
between them only through a backup file (Back up in one, Restore in the
other). Uninstalling one never touches the other. Use HaraPlay Dev for
testing and keep the release app for everyday listening.

```bash
# Debug APK (build/app/outputs/flutter-apk/app-debug.apk)
flutter build apk --debug

# Release APK, signed (build/app/outputs/flutter-apk/app-release.apk)
flutter build apk --release

# Install / update on a connected phone (-r keeps the app's data)
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

A new release APK installs over the old one and keeps its data, as long as
it is signed with the same release key.

### Release signing

Release signing reads `android/key.properties` (git-ignored), which holds
`storeFile`, `storePassword`, `keyAlias` and `keyPassword`. The keystore
itself lives outside the repository (`storeFile` points to it). Without
`key.properties` the release APK is built **unsigned**, so it won't
install; it is never silently signed with the debug key.

**Never commit or lose** the keystore or `key.properties`. Keep a copy of
both somewhere safe, off this machine. Without the original key, an update
can't be installed over the existing release app: it would have to be
uninstalled first, losing its data (a backup file would bring the data
back).

## Tools

- `dart run tool/gen_icons.dart`: regenerates `HaraIcons` from
  `tool/icons.txt` (Lucide names).
- `tool/make_launcher_icons.sh` / `tool/make_launcher_icons.sh dev`:
  renders the launcher icons (release / HaraPlay Dev) from `tool/icon/`
  (needs ImageMagick with librsvg).
- `tool/make_test_audio.sh <dir>`: tagged test tones (needs ffmpeg) to
  push to an emulator, e.g. `adb push <dir>/. "/sdcard/Music/HaraPlay Samples"`.
- `tool/make_gapless_audio.sh`, `tool/make_replaygain_audio.sh`,
  `tool/make_lyrics_audio.sh`, `tool/make_bulk_audio.sh`: fixtures for the
  gapless, ReplayGain, lyrics and large-library checks.

## License

MIT — see [`LICENSE`](LICENSE). Bundled fonts and icons are listed in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
