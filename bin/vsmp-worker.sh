#!/bin/sh
# vsmp-worker.sh — the tick loop. Every CHECK_SEC it computes the correct frame
# from ELAPSED REAL TIME (not a counter), so it self-corrects across sleeps,
# reboots and missed ticks. On a frame CHANGE it does a clean full update; on an
# unchanged tick it quietly re-asserts the current frame (no flash) so the image
# survives external clears (e.g. plugging in a charger). Started/stopped by
# vsmp.sh — don't run directly.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
CHECK_SEC=60                      # re-assert cadence — bounds any blank window

while :; do
  [ -f "$STATE_FILE" ] || exit 0
  . "$STATE_FILE"
  [ "$STATUS" = "playing" ] || [ "$STATUS" = "ended" ] || exit 0

  prevent_ss                      # re-assert "don't sleep the screen" every tick

  now=$(date +%s)
  elapsed=$(( now - START_EPOCH - PAUSED_ACCUM ))
  [ "$elapsed" -lt 0 ] && elapsed=0

  idx=$(awk -v e="$elapsed" -v t="$TOTAL_FRAMES" -v d="$DURATION_SEC" \
        'BEGIN{ if(d<=0){print 0; exit} i=int(e*t/d); if(i>=t)i=t-1; if(i<0)i=0; print i }')
  fr=$(printf "%s/frame_%05d.png" "$FRAME_DIR" $(( idx + 1 )))

  if [ "$idx" != "$LAST_FRAME" ]; then
    if [ -f "$fr" ]; then
      "$EIPS" -N 0 -f -g "$fr" >/dev/null 2>&1     # changed: clean full update
      set_state LAST_FRAME "$idx"
      echo "$(date '+%Y-%m-%d %H:%M:%S') frame $idx" >> "$LOG_FILE"
    fi
  else
    [ -f "$fr" ] && "$EIPS" -N 0 -g "$fr" >/dev/null 2>&1   # unchanged: quiet re-assert (no flash)
  fi

  # at the end: mark ended once, then keep re-asserting the final frame (don't exit,
  # so the final frame survives charger/clear events too).
  if [ "$elapsed" -ge "$DURATION_SEC" ] && [ "$STATUS" != "ended" ]; then
    set_state STATUS ended
    echo "$(date '+%Y-%m-%d %H:%M:%S') movie ended — holding final frame" >> "$LOG_FILE"
  fi

  sleep "$CHECK_SEC"
done
