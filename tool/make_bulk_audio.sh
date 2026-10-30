#!/usr/bin/env bash
# Makes a large library for performance checks: N untagged 31-second silent
# MP3s named "Artist NNN - Word Word NNNN.mp3" (so the file-name rule fills
# in artists), 100 per folder. Files are hard links to one ~31 KB source.
#
# Usage: tool/make_bulk_audio.sh <output-dir> [count=5000]
#   then: adb push <output-dir>/. "/sdcard/Music/Bulk Test"
#   and:  adb shell content call --method scan_volume --uri content://media \
#           --arg external_primary
set -euo pipefail

out="${1:?usage: $0 <output-dir> [count]}"
count="${2:-5000}"
mkdir -p "$out"
src="$out/.silence.mp3"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "anullsrc=r=8000:cl=mono" \
  -t 31 -c:a libmp3lame -b:a 8k "$src"

words=(Amber Neon Velvet Paper Echo Harbor Copper Lantern Signal Willow Static \
  Orbit Cinder Juniper Marble Ripple)
RANDOM=7
for ((i = 0; i < count; i++)); do
  folder=$(printf '%s/Album %02d' "$out" $((i / 100)))
  mkdir -p "$folder"
  artist=$(printf 'Artist %03d' $((RANDOM % 120)))
  title=$(printf '%s %s %04d' "${words[RANDOM % 16]}" "${words[RANDOM % 16]}" "$i")
  ln "$src" "$folder/$artist - $title.mp3"
done
rm "$src"
echo "$count files in $out"
