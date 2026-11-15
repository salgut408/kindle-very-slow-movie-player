#!/bin/sh
# ===== Very Slow Movie Player: configuration (separate from weather app) =====
MOVIE_NAME="metropolis"             # current movie
PLAYBACK_DAYS="9"                  # target run time (7–10.5 typical); configurable
INTERVAL_MIN="2"                   # minutes between frame changes
SCREEN_W="1236"
SCREEN_H="1648"

# On-Kindle paths (kept entirely separate from /mnt/us/dashboard)
VSMP_ROOT="/mnt/us/vsmp"
BIN_DIR="$VSMP_ROOT/bin"
FRAME_DIR="$VSMP_ROOT/frames"
STATE_DIR="$VSMP_ROOT/state"
STATE_FILE="$STATE_DIR/playback.env"
LOG_FILE="$VSMP_ROOT/vsmp.log"

# Native e-ink image tool (FBInk here is Image=No, so we use eips)
EIPS="/usr/sbin/eips"

# The weather app's loop control (shared, never modified) — used by the switch
WEATHER_LOOP="/mnt/us/dashboard/bin/dashboard-loop.sh"

# --- state helpers (POSIX sh / busybox) ---
set_state() {   # set_state KEY VALUE  (persists to STATE_FILE)
  k="$1"; v="$2"
  mkdir -p "$STATE_DIR"
  if [ -f "$STATE_FILE" ] && grep -q "^$k=" "$STATE_FILE" 2>/dev/null; then
    sed -i "s|^$k=.*|$k=$v|" "$STATE_FILE"
  else
    echo "$k=$v" >> "$STATE_FILE"
  fi
}
prevent_ss() { lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null; }
