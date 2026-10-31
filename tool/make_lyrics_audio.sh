#!/usr/bin/env bash
# Generates test songs for the lyrics feature (A2). All audio and lyrics are
# original and synthesised here.
#
#   "Lantern Lines.mp3" + "Lantern Lines.lrc"  synced sidecar file, with an
#                                              [offset:] tag, metadata tags and
#                                              a line with two timestamps
#   "Copper Verses.mp3"                        synced lyrics embedded (ID3 USLT)
#   "Paper Echo.flac"                          plain lyrics embedded (Vorbis
#                                              LYRICS), not synced
#
# Usage: tool/make_lyrics_audio.sh <output-dir>
#   then: adb push <output-dir>/. "/sdcard/Music/HaraPlay Lyrics Test"
set -euo pipefail

out="${1:?usage: $0 <output-dir>}"
mkdir -p "$out"
ff=(ffmpeg -hide_banner -loglevel error -y)

tone() { # <freq> <seconds>
  echo "sine=frequency=$1:duration=$2:sample_rate=44100,volume=0.15"
}

# 1. Sidecar .lrc next to an MP3 with the same base name.
"${ff[@]}" -f lavfi -i "$(tone 392 40)" -c:a libmp3lame -b:a 128k \
  -id3v2_version 3 -metadata title="Lantern Lines" \
  -metadata artist="The Test Tones" -metadata album="Lyric Sketches" \
  "$out/Lantern Lines.mp3"
cat > "$out/Lantern Lines.lrc" <<'LRC'
[ti:Lantern Lines]
[ar:The Test Tones]
[al:Lyric Sketches]
[by:HaraPlay test fixture]
[offset:+500]
[00:02.50]A lantern hums a single note
[00:06.50]The hallway answers, soft and low
[00:10.50]Count the steps and count them slow
[00:14.50][00:30.50]Saffron light on the window glass
[00:18.50]
[00:22.50]Every echo finds its way back home
[00:26.50]Keep the tune and let the rest go
[00:34.50]The last bar fades, the lantern dims
LRC

# 2. Synced lyrics inside the MP3 (ID3v2.3 USLT). ffmpeg only writes a TXXX
#    frame for lyrics, so the tag is built here and put in front of the
#    audio stream.
"${ff[@]}" -f lavfi -i "$(tone 523 40)" -c:a libmp3lame -b:a 128k \
  -write_id3v2 0 -write_xing 0 "$out/.copper.raw.mp3"
python3 -I - "$out/.copper.raw.mp3" "$out/Copper Verses.mp3" <<'PY'
import struct, sys

def frame(fid, body):
    return fid.encode() + struct.pack('>I', len(body)) + b'\0\0' + body

def text(fid, value):  # encoding 1: UTF-16 with BOM
    return frame(fid, b'\x01' + value.encode('utf-16'))

lyrics = '\n'.join([
    '[00:02.00]Copper wire and a quiet room',
    '[00:06.00]Two notes lean against the tune',
    '[00:10.00]Turn it down, the night is near',
    '[00:14.00]Every verse ends somewhere here',
    '[00:20.00]Hold the chord a little more',
    '[00:26.00]Then let it drift across the floor',
])
uslt = frame('USLT', b'\x01' + b'eng' + ''.encode('utf-16') + b'\0\0'
             + lyrics.encode('utf-16'))
frames = (text('TIT2', 'Copper Verses') + text('TPE1', 'The Test Tones')
          + text('TALB', 'Lyric Sketches') + uslt)
size = len(frames)
syncsafe = bytes([(size >> 21) & 0x7F, (size >> 14) & 0x7F,
                  (size >> 7) & 0x7F, size & 0x7F])
with open(sys.argv[1], 'rb') as audio, open(sys.argv[2], 'wb') as dest:
    dest.write(b'ID3\x03\x00\x00' + syncsafe + frames + audio.read())
PY
rm "$out/.copper.raw.mp3"

# 3. Plain, unsynced lyrics in a FLAC Vorbis comment.
"${ff[@]}" -f lavfi -i "$(tone 659 30)" -c:a flac \
  -metadata title="Paper Echo" -metadata artist="The Test Tones" \
  -metadata album="Lyric Sketches" \
  -metadata LYRICS="$(printf 'Paper folds and paper sings\nA tone that never asks for much\n\nRead it slowly, read it twice\nThen put it back where it belongs')" \
  "$out/Paper Echo.flac"

echo "Lyrics test songs in $out"
