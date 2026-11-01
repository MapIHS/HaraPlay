# Third-party notices

HaraPlay is licensed under the MIT License (see `LICENSE`). It bundles the
following third-party assets, each under its own license. The full license
text for every bundled asset ships next to it under `assets/`.

| Asset | Source | License | License file |
|---|---|---|---|
| Bricolage Grotesque (variable) | [google/fonts `ofl/bricolagegrotesque`](https://github.com/google/fonts/tree/main/ofl/bricolagegrotesque) — upstream [ateliertriay/bricolage](https://github.com/ateliertriay/bricolage) | SIL Open Font License 1.1 | `assets/fonts/bricolage_grotesque/OFL.txt` |
| DM Sans (variable, roman + italic) | [google/fonts `ofl/dmsans`](https://github.com/google/fonts/tree/main/ofl/dmsans) — upstream [googlefonts/dm-fonts](https://github.com/googlefonts/dm-fonts) | SIL Open Font License 1.1 | `assets/fonts/dm_sans/OFL.txt` |
| Space Mono (Regular, Bold) | [google/fonts `ofl/spacemono`](https://github.com/google/fonts/tree/main/ofl/spacemono) — upstream [googlefonts/spacemono](https://github.com/googlefonts/spacemono) | SIL Open Font License 1.1 | `assets/fonts/space_mono/OFL.txt` |
| Lucide icon font (`lucide.ttf`, v1.64.0) | npm [`lucide-static@1.64.0`](https://www.npmjs.com/package/lucide-static) — [lucide.dev](https://lucide.dev) | ISC License | `assets/icons/lucide/LICENSE` |

The fonts are bundled unmodified; none declares a Reserved Font Name.
`tool/lucide_codepoints.json` (from the same `lucide-static` release) is used
only at development time to generate `lib/core/icons/hara_icons.dart`.

## Libraries built into the app

The Android app (APK) also contains these libraries, linked in by Flutter and
the Dart packages above. They are used unmodified.

| Library | Used for | License |
|---|---|---|
| [AndroidX / Jetpack](https://developer.android.com/jetpack/androidx) (`androidx.*`: core, appcompat, activity, fragment, lifecycle, media, datastore, window and their dependencies) | Android framework support, media session | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| [AndroidX Media3 / ExoPlayer](https://github.com/androidx/media) (`androidx.media3:*` 1.4.x, via `just_audio`) | Audio playback | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| [Kotlin standard library, kotlinx.coroutines, kotlinx.serialization](https://kotlinlang.org) (`org.jetbrains.kotlin*`) | Android-side code | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| [Guava](https://github.com/google/guava) (`com.google.guava:*`) | Media3 dependency | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| [Okio](https://github.com/square/okio) (`com.squareup.okio:*`) | AndroidX DataStore dependency | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| [ReLinker](https://github.com/KeepSafe/ReLinker) (`com.getkeepsafe.relinker`) | Loading native libraries | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| [JetBrains Java Annotations](https://github.com/JetBrains/java-annotations), [JSpecify](https://jspecify.dev) | Annotations | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
| [Flutter engine](https://github.com/flutter/flutter) (`io.flutter:*`) | The app runtime | [BSD 3-Clause](https://github.com/flutter/flutter/blob/master/LICENSE) (its own third-party components are listed in the in-app license page) |
| [SQLite](https://sqlite.org) (via the `sqlite3` package) | The library database | [Public domain](https://sqlite.org/copyright.html) |

The exact Android library versions are those resolved by Gradle for the
release build (`./gradlew app:dependencies --configuration
releaseRuntimeClasspath` in `android/`).

Dart/Flutter package dependencies are listed in `pubspec.yaml`; their licenses
are shown in-app via Settings → About → Open-source licenses.

HaraPlay contains no code or assets from the `nuclear` or `omniplay`
projects; they were used only as visual and behavioural references.
