#!/bin/sh
# extract-frames.sh <movie> <out_dir> <num_frames> [start_seconds]  (run on the Mac)
# Samples <num_frames> evenly across the film (from start_seconds to the end) and
# writes letterboxed, grayscale PNGs sized to the Kindle screen (1236x1648) for eips.
export PATH="/opt/homebrew/bin:$PATH"
set -e
MOVIE="$1"; OUT="$2"; N="$3"; START="${4:-0}"
W=1236; H=1648
[ -z "$N" ] && { echo "usage: extract-frames.sh <movie> <out_dir> <num_frames> [start_seconds]"; exit 1; }
[ -f "$MOVIE" ] || { echo "no such movie: $MOVIE"; exit 1; }

DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$MOVIE")
REMAIN=$(awk -v d="$DUR" -v s="$START" 'BEGIN{ printf "%.3f", d-s }')
echo "movie:     $MOVIE"
echo "duration:  ${DUR}s   start: ${START}s   remaining: ${REMAIN}s"
# output fps so that N frames span the REMAINING footage after the start offset
FPS=$(awk -v n="$N" -v r="$REMAIN" 'BEGIN{ printf "%.6f", n/r }')
echo "sampling:  $N frames from ${START}s onward  (output fps $FPS)"

mkdir -p "$OUT"
rm -f "$OUT"/frame_*.png
# -ss before -i: seek to the start offset; fps filter then samples from there
ffmpeg -hide_banner -loglevel error -ss "$START" -i "$MOVIE" \
  -vf "fps=${FPS},scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black,format=gray,eq=contrast=1.06" \
  -frames:v "$N" \
  "$OUT/frame_%05d.png"

GOT=$(ls "$OUT"/frame_*.png 2>/dev/null | wc -l | tr -d ' ')
BYTES=$(du -sk "$OUT" | awk '{print $1}')
echo "extracted: $GOT frames"
echo "size:      $((BYTES/1024)) MB  (avg $((BYTES/GOT)) KB/frame)"
