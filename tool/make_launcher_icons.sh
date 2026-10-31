#!/usr/bin/env bash
# Renders the launcher icons from tool/icon/*.svg (needs ImageMagick with
# librsvg). Run from the haraplay/ directory: tool/make_launcher_icons.sh
set -euo pipefail

res=android/app/src/main/res
icon=tool/icon/haraplay_icon.svg
fg=tool/icon/haraplay_foreground.svg
mono=tool/icon/haraplay_monochrome.svg

render() { # svg size out [mask]
  magick -background none -density 384 "$1" -resize "$2x$2" "$3"
}

# density: legacy launcher size, adaptive layer size
for spec in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  IFS=: read -r d size layer <<<"$spec"
  dir=$res/mipmap-$d
  mkdir -p "$dir"
  # Legacy (API 24-25): rounded square, and a round variant.
  r=$((size * 22 / 100))
  render "$icon" "$size" /tmp/hara_icon_full.png
  magick /tmp/hara_icon_full.png \
    \( -size "${size}x${size}" xc:black -fill white \
       -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $r,$r" \) \
    -alpha off -compose CopyOpacity -composite "$dir/ic_launcher.png"
  magick /tmp/hara_icon_full.png \
    \( -size "${size}x${size}" xc:black -fill white \
       -draw "circle $((size / 2)),$((size / 2)) $((size / 2)),0" \) \
    -alpha off -compose CopyOpacity -composite "$dir/ic_launcher_round.png"
  # Adaptive layers (API 26+).
  render "$fg" "$layer" "$dir/ic_launcher_foreground.png"
  render "$mono" "$layer" "$dir/ic_launcher_monochrome.png"
done
rm -f /tmp/hara_icon_full.png
echo "Launcher icons written to $res/mipmap-*"
