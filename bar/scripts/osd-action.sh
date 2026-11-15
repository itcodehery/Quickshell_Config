#!/usr/bin/env bash
set -euo pipefail

QS_BARCTL="$HOME/.config/quickshell/bin/qs-barctl"
MODE="${1:-}"
ARG="${2:-}"

case "$MODE" in
  volume)
    case "$ARG" in
      raise)       wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
      lower)       wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
      +1)          wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 1%+ ;;
      -1)          wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%- ;;
      mute-toggle) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    esac
    info="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
    pct="$(awk '{ printf "%d\n", ($2 * 100) + 0.5 }' <<< "$info" 2>/dev/null || echo 0)"
    if grep -q '\[MUTED\]' <<< "$info"; then
      "$QS_BARCTL" ipc osd show audio-muted "$pct" >/dev/null 2>&1 || true
    else
      "$QS_BARCTL" ipc osd show audio "$pct" >/dev/null 2>&1 || true
    fi
    ;;
  brightness)
    [ -n "$ARG" ] && brightnessctl set "$ARG" >/dev/null 2>&1 || true
    pct="$(brightnessctl -m 2>/dev/null | awk -F, '{ gsub(/%/, "", $4); print $4; exit }' || echo 0)"
    "$QS_BARCTL" ipc osd show brightness "${pct:-0}" >/dev/null 2>&1 || true
    ;;
esac
