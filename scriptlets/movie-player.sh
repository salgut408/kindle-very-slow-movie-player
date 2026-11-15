#!/bin/sh
# Name: Movie Player
# Author: VSMP
# Tapping this in the library switches the Kindle to dedicated Very Slow Movie
# Player mode (stops the UI framework, stops the weather loop, resumes the film).
if [ "$1" != "--detached" ]; then
    # detach so we survive the library launcher + framework being stopped
    if command -v setsid > /dev/null 2>&1; then
        setsid sh /mnt/us/documents/movie-player.sh --detached >/dev/null 2>&1 < /dev/null &
    else
        nohup sh /mnt/us/documents/movie-player.sh --detached >/dev/null 2>&1 < /dev/null &
    fi
    exit 0
fi
sleep 2                                                   # let the launcher return home first
/mnt/us/dashboard/bin/kindle-ui.sh stop >/dev/null 2>&1   # dedicated display (no touch/repaint)
/mnt/us/vsmp/bin/display-mode.sh vsmp    >/dev/null 2>&1   # weather off, movie on
