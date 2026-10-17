#!/usr/bin/env bash
# Hardware privacy monitor: checks microphone, camera, and screen recording/capture
set -u

mic_count=$(pactl list source-outputs 2>/dev/null | grep -c "Corked: no" || true)
[ -z "$mic_count" ] && mic_count=0

cam_count=$(fuser /dev/video* 2>/dev/null | wc -w || true)
[ -z "$cam_count" ] && cam_count=0

screen_active=0
[ -f /tmp/omarchy-screenrecord-filename ] && screen_active=1
pgrep -x wf-recorder >/dev/null 2>&1 && screen_active=1
pgrep -x obs >/dev/null 2>&1 && screen_active=1

printf '{"mic":%d,"cam":%d,"screen":%d}\n' \
  "$([ "$mic_count" -gt 0 ] && echo 1 || echo 0)" \
  "$([ "$cam_count" -gt 0 ] && echo 1 || echo 0)" \
  "$screen_active"
