#!/usr/bin/env bash
# Generates a ReplayGain test album: the same 440 Hz tone three times, as
# FLAC (track gain -6.02 dB, album gain -12.04 dB), MP3 (ID3v2.3 TXXX track
# gain -12.04 dB) and AAC (no tags). With ReplayGain on Track, the three
# should play at half, a quarter and full amplitude; on Off, all at full.
# All audio is synthesised here. The tracks are 8 s long, so turn
# "Hide short audio" off while testing.
#
# Usage: tool/make_replaygain_audio.sh <output-dir>
#   then: adb push <output-dir>/. "/sdcard/Music/HaraPlay RG Test"
set -euo pipefail

out="${1:?usage: $0 <output-dir>}"
mkdir -p "$out"
ff=(ffmpeg -hide_banner -loglevel error -y)
src=(-f lavfi -i "sine=frequency=440:sample_rate=44100:duration=8,volume=0.5")
album=(-metadata "artist=The Test Tones" -metadata "album_artist=The Test Tones"
  -metadata "album=ReplayGain Test")

"${ff[@]}" "${src[@]}" -c:a flac "${album[@]}" \
  -metadata "title=RG Minus 6 (flac)" -metadata track=1/3 \
  -metadata "REPLAYGAIN_TRACK_GAIN=-6.02 dB" \
  -metadata "REPLAYGAIN_ALBUM_GAIN=-12.04 dB" \
  "$out/01 RG Minus 6.flac"
"${ff[@]}" "${src[@]}" -c:a libmp3lame -b:a 192k -id3v2_version 3 "${album[@]}" \
  -metadata "title=RG Minus 12 (mp3)" -metadata track=2/3 \
  -metadata "REPLAYGAIN_TRACK_GAIN=-12.04 dB" \
  "$out/02 RG Minus 12.mp3"
"${ff[@]}" "${src[@]}" -c:a aac -b:a 192k "${album[@]}" \
  -metadata "title=RG None (m4a)" -metadata track=3/3 \
  "$out/03 RG None.m4a"
echo "ReplayGain test album in $out"
