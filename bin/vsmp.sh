#!/bin/sh
# vsmp.sh — Very Slow Movie Player control.
# Commands:
#   start [days]      begin playback from the top (default PLAYBACK_DAYS)
#   pause             freeze on the current frame
#   resume            continue from where it was
#   stop              halt + hand the screen back to the weather dashboard
#   restart           start the current movie over from frame 1
#   status            progress, current frame, time remaining
#   set-duration D    change target run length to D days (reschedules pacing)
#   load NAME DAYS    switch to a different frame set and start it
#   _halt             (internal) stop the worker only
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
PIDFILE="$STATE_DIR/worker.pid"

worker_running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

count_frames() { ls "$FRAME_DIR"/frame_*.png 2>/dev/null | wc -l | tr -d ' '; }

launch_worker() {
  worker_running && return 0
  prevent_ss
  if command -v setsid >/dev/null 2>&1; then
    setsid "$BIN_DIR/vsmp-worker.sh" >/dev/null 2>&1 &
  else
    nohup "$BIN_DIR/vsmp-worker.sh" >/dev/null 2>&1 &
  fi
  echo $! > "$PIDFILE"
}

halt_worker() {
  if worker_running; then kill "$(cat "$PIDFILE")" 2>/dev/null; fi
  rm -f "$PIDFILE"
}

begin() {   # begin <days> — fresh playback
  days="${1:-$PLAYBACK_DAYS}"
  total=$(count_frames)
  if [ "$total" -lt 1 ]; then echo "No frames in $FRAME_DIR — deploy frames first."; exit 1; fi
  mkdir -p "$STATE_DIR"; : > "$STATE_FILE"
  set_state MOVIE "$MOVIE_NAME"
  set_state TOTAL_FRAMES "$total"
  set_state DURATION_SEC $(awk -v d="$days" 'BEGIN{printf "%d", d*86400}')
  set_state START_EPOCH "$(date +%s)"
  set_state PAUSED_ACCUM 0
  set_state PAUSE_START 0
  set_state LAST_FRAME "-1"
  set_state STATUS playing
  launch_worker
  echo "Started '$MOVIE_NAME': $total frames over $days days (frame every $INTERVAL_MIN min)."
}

[ -f "$STATE_FILE" ] && . "$STATE_FILE"

case "$1" in
  start)    "$WEATHER_LOOP" stop >/dev/null 2>&1; begin "$2" ;;
  _halt)    halt_worker ;;
  pause)
    halt_worker
    set_state PAUSE_START "$(date +%s)"
    set_state STATUS paused
    echo "Paused on frame ${LAST_FRAME:-0}."
    ;;
  resume)
    [ "$STATUS" = "ended" ] && { echo "Movie already ended. Use restart."; exit 0; }
    if [ "${PAUSE_START:-0}" -gt 0 ]; then
      add=$(( $(date +%s) - PAUSE_START ))
      set_state PAUSED_ACCUM $(( ${PAUSED_ACCUM:-0} + add ))
      set_state PAUSE_START 0
    fi
    set_state STATUS playing
    "$WEATHER_LOOP" stop >/dev/null 2>&1
    launch_worker
    echo "Resumed."
    ;;
  restart)  "$WEATHER_LOOP" stop >/dev/null 2>&1; begin "${2:-$PLAYBACK_DAYS}" ;;
  stop)
    halt_worker
    set_state STATUS stopped
    echo "Stopped. Handing screen back to the weather dashboard..."
    "$WEATHER_LOOP" start >/dev/null 2>&1
    ;;
  set-duration)
    [ -z "$2" ] && { echo "usage: vsmp.sh set-duration <days>"; exit 1; }
    # keep the CURRENT frame, apply the new pace from here (no jump)
    now=$(date +%s)
    el=$(( now - ${START_EPOCH:-now} - ${PAUSED_ACCUM:-0} )); [ "$el" -lt 0 ] && el=0
    curidx=$(awk -v e="$el" -v t="${TOTAL_FRAMES:-1}" -v d="${DURATION_SEC:-1}" \
             'BEGIN{i=int(e*t/d); if(i>=t)i=t-1; if(i<0)i=0; print i}')
    newdur=$(awk -v d="$2" 'BEGIN{printf "%d", d*86400}')
    newstart=$(awk -v n="$now" -v i="$curidx" -v t="${TOTAL_FRAMES:-1}" -v nd="$newdur" \
               'BEGIN{printf "%d", n - (i/t)*nd}')
    set_state DURATION_SEC "$newdur"
    set_state PAUSED_ACCUM 0
    set_state PAUSE_START 0
    set_state START_EPOCH "$newstart"
    echo "Duration set to $2 days — kept frame $curidx, new pace applies from here."
    ;;
  load)
    [ -z "$2" ] && { echo "usage: vsmp.sh load <movie_name> [days]"; exit 1; }
    MOVIE_NAME="$2"
    echo "NOTE: ensure $FRAME_DIR holds the '$2' frames (deploy them first)."
    "$WEATHER_LOOP" stop >/dev/null 2>&1; begin "${3:-$PLAYBACK_DAYS}"
    ;;
  status)
    if [ ! -f "$STATE_FILE" ]; then echo "No movie loaded."; exit 0; fi
    now=$(date +%s)
    el=$(( now - ${START_EPOCH:-now} - ${PAUSED_ACCUM:-0} ))
    [ "$el" -lt 0 ] && el=0
    awk -v s="${STATUS:-?}" -v el="$el" -v d="${DURATION_SEC:-1}" -v lf="${LAST_FRAME:-0}" \
        -v t="${TOTAL_FRAMES:-0}" -v m="${MOVIE:-?}" 'BEGIN{
      p = (d>0)? el/d*100 : 0; if(p>100)p=100;
      rem = d-el; if(rem<0)rem=0;
      printf "Movie:    %s\nStatus:   %s\nProgress: %.1f%%  (frame %d / %d)\n", m, s, p, lf+1, t;
      printf "Elapsed:  %.1f days\nRemaining:%.1f days\n", el/86400, rem/86400;
    }'
    worker_running && echo "Worker:   running" || echo "Worker:   not running"
    ;;
  *)
    echo "usage: vsmp.sh {start [days]|pause|resume|stop|restart|status|set-duration D|load NAME [days]}"
    exit 1 ;;
esac
