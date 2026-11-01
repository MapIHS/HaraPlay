#!/usr/bin/env bash
# Generates a gapless test album: one continuous 440 Hz tone cut into three
# tracks at sample-exact points that don't line up with codec frames, in
# FLAC, MP3 and AAC (M4A). Played in a row, there must be no gap or click
# where one track hands over to the next. All audio is synthesised here.
#
# Usage: tool/make_gapless_audio.sh <output-dir>
#   then: adb push <output-dir>/. "/sdcard/Music/HaraPlay Gapless Test"
set -euo pipefail

out="${1:?usage: $0 <output-dir>}"
mkdir -p "$out"
ff=(ffmpeg -hide_banner -loglevel error -y)
rate=44100
# Cut points in samples (about 31 s apart, so "Hide short audio" keeps
# them), plus a few odd samples so no cut lines up with a codec frame.
cuts=(0 1371651 2831630 4365000)

"${ff[@]}" -f lavfi -i "sine=frequency=440:sample_rate=$rate:duration=99.1,volume=0.3" \
  -c:a pcm_s16le "$out/.source.wav"

for fmt in flac mp3 m4a; do
  dir="$out/$fmt"
  mkdir -p "$dir"
  for n in 1 2 3; do
    start=${cuts[$((n - 1))]}
    end=${cuts[$n]}
    case $fmt in
      flac) codec=(-c:a flac) ;;
      mp3) codec=(-c:a libmp3lame -b:a 192k) ;;
      m4a) codec=(-c:a aac -b:a 192k) ;;
    esac
    "${ff[@]}" -i "$out/.source.wav" \
      -af "atrim=start_sample=$start:end_sample=$end,asetpts=PTS-STARTPTS" \
      "${codec[@]}" \
      -metadata title="Gapless Part $n ($fmt)" -metadata artist="The Test Tones" \
      -metadata album="Gapless Test ($fmt)" -metadata album_artist="The Test Tones" \
      -metadata track="$n/3" \
      "$dir/0$n Gapless Part $n.$fmt"
  done
done
rm "$out/.source.wav"
echo "Gapless test album in $out (flac, mp3, m4a)"
