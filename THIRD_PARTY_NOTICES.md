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

Dart/Flutter package dependencies are listed in `pubspec.yaml`; their licenses
are shown in-app via Settings → About → Licenses.

HaraPlay contains no code or assets from the `nuclear` or `omniplay`
projects; they were used only as visual and behavioural references.
