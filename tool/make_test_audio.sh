#!/usr/bin/env bash
# Generates short tone files in several formats and tag layouts, for testing
# the library scan on an emulator. All audio and artwork are synthesised here.
#
# Usage: tool/make_test_audio.sh <output-dir>
#   then: adb push <output-dir>/. "/sdcard/Music/HaraPlay Samples"
set -euo pipefail

out="${1:?usage: $0 <output-dir>}"
mkdir -p "$out/Live" "$out/.covers"
ff=(ffmpeg -hide_banner -loglevel error -y)

# Square covers: a saffron and a sky-blue field with a dark frame.
"${ff[@]}" -f lavfi -i "color=c=0xFFC738:s=600x600,drawbox=x=90:y=90:w=420:h=420:color=0x16130C:t=24" \
  -frames:v 1 "$out/.covers/saffron.jpg"
"${ff[@]}" -f lavfi -i "color=c=0xBCD9FF:s=600x600,drawbox=x=150:y=150:w=300:h=300:color=0x16130C:t=fill" \
  -frames:v 1 "$out/.covers/sky.jpg"

tone() { # <freq> <seconds> <rate>
  echo "sine=frequency=$1:duration=$2:sample_rate=$3,volume=0.15"
}

# 1-2. MP3 album with embedded cover, track/disc tags, album artist.
for n in 1 2; do
  "${ff[@]}" -f lavfi -i "$(tone $((330 + n * 110)) 40 44100)" -i "$out/.covers/saffron.jpg" \
    -map 0 -map 1 -c:a libmp3lame -b:a 128k -c:v copy -id3v2_version 3 \
    -disposition:v attached_pic \
    -metadata title="Saffron Sunrise Part $n" -metadata artist="The Test Tones" \
    -metadata album="Saffron Sessions" -metadata album_artist="The Test Tones" \
    -metadata genre="Electronic" -metadata date=2024 -metadata track="$n/3" \
    "$out/0$n Saffron Sunrise Part $n.mp3"
done

# 3. FLAC 48 kHz / 24-bit in the same album, with an embedded picture.
"${ff[@]}" -f lavfi -i "$(tone 660 45 48000)" -i "$out/.covers/saffron.jpg" \
  -map 0 -map 1 -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 -c:v copy \
  -disposition:v attached_pic \
  -metadata title="Saffron Sunset (Lossless)" -metadata artist="The Test Tones" \
  -metadata album="Saffron Sessions" -metadata album_artist="The Test Tones" \
  -metadata genre="Electronic" -metadata date=2024 -metadata track="3/3" \
  "$out/03 Saffron Sunset.flac"

# 4. Ogg Vorbis, different genre and year, no artwork.
"${ff[@]}" -f lavfi -i "$(tone 247 38 44100)" -c:a libvorbis -q:a 3 \
  -metadata title="Night Drive" -metadata artist="Mono Lisa" \
  -metadata album="Night Drive" -metadata genre="Synthwave" -metadata date=2019 \
  -metadata tracknumber=1 \
  "$out/Night Drive.ogg"

# 5. AAC in M4A: disc 2 of a compilation (album artist differs from artist).
"${ff[@]}" -f lavfi -i "$(tone 523 42 44100)" -i "$out/.covers/sky.jpg" \
  -map 0 -map 1 -c:a aac -b:a 128k -c:v copy -disposition:v attached_pic \
  -metadata title="Disc Two Opener" -metadata artist="Kai Tone" \
  -metadata album="Double Feature" -metadata album_artist="Various Artists" \
  -metadata genre="Jazz" -metadata date=2015 -metadata track="1/8" -metadata disc="2/2" \
  "$out/Live/2-01 Disc Two Opener.m4a"

# 6. Opus with only title and artist (no album).
"${ff[@]}" -f lavfi -i "$(tone 392 36 48000)" -c:a libopus -b:a 64k \
  -metadata title="Opus Number One" -metadata artist="Kai Tone" \
  "$out/Live/Opus Number One.opus"

# 7. MP3 with accented tags (search normalisation later). ID3v2.4 stores
# UTF-8; with v2.3 ffmpeg writes Latin-1, which Android may decode with the
# wrong code page (ñ shows up as ń).
"${ff[@]}" -f lavfi -i "$(tone 294 40 44100)" -c:a libmp3lame -b:a 96k -id3v2_version 4 \
  -metadata title="Señorita Café" -metadata artist="Beyoncé Sinewave" \
  -metadata album="Ünïcode Dreams" -metadata genre="Pop" -metadata date=2022 \
  "$out/Senorita Cafe.mp3"

# 8. Untagged WAV: the title must fall back to the file name.
"${ff[@]}" -f lavfi -i "$(tone 196 35 44100)" -c:a pcm_s16le \
  "$out/untitled field recording.wav"

# 9. A 10-second jingle, below the default 30 s minimum duration (M4).
"${ff[@]}" -f lavfi -i "$(tone 880 10 44100)" -c:a libmp3lame -b:a 96k \
  -metadata title="Short Jingle" -metadata artist="The Test Tones" \
  "$out/Short Jingle.mp3"

rm -r "$out/.covers"
find "$out" -type f | sort
