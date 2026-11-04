#!/usr/bin/env bash
# Generates tone files for checking cover art on an emulator: a sharp
# square checkerboard cover embedded in a wide 1600x900 picture (as audio
# saved from video sites often has), and a song without an embedded
# picture next to a 1200x1200 cover.jpg. All audio and artwork are
# synthesised here.
#
# Usage: tool/make_artwork_audio.sh <output-dir>
#   then: adb push <output-dir>/. "/sdcard/Music/HaraPlay Art Test"
set -euo pipefail

out="${1:?usage: $0 <output-dir>}"
mkdir -p "$out/Wide" "$out/Folder" "$out/.covers"
ff=(ffmpeg -hide_banner -loglevel error -y)

# A fine checkerboard (8 px squares): blur from upscaling is easy to see.
checker() { # <size> <colour> <output>
  "${ff[@]}" -f lavfi \
    -i "color=c=$2:s=$1x$1,geq=lum='if(eq(mod(floor(X/8)+floor(Y/8),2),0),40,220)':cb=128:cr=128" \
    -frames:v 1 "$3"
}
checker 900 white "$out/.covers/square.png"
# Pillarboxed: the 900x900 cover in the middle of a black 1600x900 frame.
"${ff[@]}" -i "$out/.covers/square.png" \
  -vf "pad=1600:900:350:0:black" -q:v 2 -frames:v 1 "$out/.covers/wide.jpg"
checker 1200 white "$out/.covers/folder.png"
"${ff[@]}" -i "$out/.covers/folder.png" -q:v 2 -frames:v 1 "$out/Folder/cover.jpg"

tone() { echo "sine=frequency=$1:duration=30:sample_rate=44100,volume=0.15"; }

"${ff[@]}" -f lavfi -i "$(tone 440)" -i "$out/.covers/wide.jpg" \
  -map 0 -map 1 -c:a libmp3lame -b:a 128k -c:v copy -id3v2_version 3 \
  -disposition:v attached_pic \
  -metadata title="Wide Cover" -metadata artist="The Test Tones" \
  -metadata album="Wide Cover Test" "$out/Wide/Wide Cover.mp3"

"${ff[@]}" -f lavfi -i "$(tone 550)" -c:a libmp3lame -b:a 128k \
  -metadata title="Folder Cover" -metadata artist="The Test Tones" \
  -metadata album="Folder Cover Test" "$out/Folder/Folder Cover.mp3"

rm -r "$out/.covers"
echo "Wrote $(find "$out" -type f | wc -l) files to $out"
