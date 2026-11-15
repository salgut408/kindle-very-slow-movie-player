#!/bin/sh
# display-mode.sh {weather|vsmp|status} — switch which app owns the E-Ink screen.
# Guarantees mutual exclusion: starting one stops the other, so they never draw
# at the same time. Extensible later (e.g. a 'sports' mode).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
OWNER_FILE="$STATE_DIR/display-owner"
mkdir -p "$STATE_DIR"

case "$1" in
  weather)
    "$BIN_DIR/vsmp.sh" _halt
    "$WEATHER_LOOP" start >/dev/null 2>&1
    echo weather > "$OWNER_FILE"
    echo "Screen owner: weather dashboard"
    ;;
  vsmp)
    "$WEATHER_LOOP" stop >/dev/null 2>&1
    if [ -f "$STATE_FILE" ]; then
      "$BIN_DIR/vsmp.sh" resume
    else
      echo "No movie loaded yet — run: vsmp.sh start"
    fi
    echo vsmp > "$OWNER_FILE"
    echo "Screen owner: movie player"
    ;;
  status)
    echo "Screen owner: $(cat "$OWNER_FILE" 2>/dev/null || echo unknown)"
    ;;
  *)
    echo "usage: display-mode.sh {weather|vsmp|status}"; exit 1 ;;
esac
