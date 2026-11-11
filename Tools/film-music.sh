#!/bin/zsh
# Lays the music under a rendered cut.   Tools/film-music.sh in.mp4 out.mp4 [music file] [offset seconds]
# The track (build/film-assets/music-take1.m4a, made in Google Flow Music, not in git) starts 2.1 s in, so
# its groove lands as the film cuts back to the widget and its return lands on the download card.
set -e
cd "$(dirname "$0")/.."
IN="$1"; OUT="$2"; MUSIC="${3:-build/film-assets/music-take1.m4a}"; AT="${4:-2.1}"
LEN=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")
FADE=$(python3 -c "print(max(0, $LEN - 2.1))")
ffmpeg -y -loglevel error -i "$IN" -ss "$AT" -i "$MUSIC" \
  -filter:a "afade=t=in:d=0.35,afade=t=out:st=$FADE:d=2.1,loudnorm=I=-16:TP=-1.5:LRA=11" \
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -t "$LEN" -movflags +faststart "$OUT"
echo "wrote $OUT"
