# HaraPlay

An offline music player for Android, built with Flutter. Plays the music
already on your device — no streaming, no account, no internet permission.

- Design and plan: [`../docs/PLAN.md`](../docs/PLAN.md)
- Reference analysis: [`../docs/ANALYSIS.md`](../docs/ANALYSIS.md)

## Requirements

- Flutter 3.47+ (Dart 3.13+)
- Android 7.0 (API 24) or newer

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

The drift database code (`*.g.dart`) is generated and committed. After
changing a table or DAO, regenerate it:

```bash
dart run build_runner build
```

Other tools:

- `dart run tool/gen_icons.dart`: regenerates `HaraIcons` from `tool/icons.txt`.
- `tool/make_test_audio.sh <dir>`: makes tagged test tones (needs ffmpeg) to
  push to an emulator, e.g. `adb push <dir>/. "/sdcard/Music/HaraPlay Samples"`.

## License

MIT — see [`LICENSE`](LICENSE). Bundled fonts and icons are listed in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
