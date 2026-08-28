#!/bin/bash
echo "called at $(date)" >> /tmp/radial_test.log
PID=$(pgrep -f "quickshell -c .*/radial$")

if [ -n "$PID" ]; then
    kill $PID
else
    quickshell -c ~/.config/quickshell/radial &
fi
