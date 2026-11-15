#!/bin/sh
# Name: Weather Dashboard
# Author: VSMP
# Tapping this in the library switches the Kindle to the weather dashboard
# (stops the movie, stops the UI framework, starts the weather loop).
if [ "$1" != "--detached" ]; then
    if command -v setsid > /dev/null 2>&1; then
        setsid sh /mnt/us/documents/weather-dashboard.sh --detached >/dev/null 2>&1 < /dev/null &
    else
        nohup sh /mnt/us/documents/weather-dashboard.sh --detached >/dev/null 2>&1 < /dev/null &
    fi
    exit 0
fi
sleep 2
/mnt/us/dashboard/bin/kindle-ui.sh stop  >/dev/null 2>&1
/mnt/us/vsmp/bin/display-mode.sh weather >/dev/null 2>&1
