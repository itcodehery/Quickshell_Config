#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
param="${2:-}"

qs_cfg="/home/hery/.config/quickshell/bar/shell.qml"
if [[ "$action" == "volume" ]]; then
    sink="$(omarchy-audio-output-sink 2>/dev/null || echo "@DEFAULT_SINK@")"
    if [[ "$param" == "mute-toggle" ]]; then
        pactl set-sink-mute "$sink" toggle 2>/dev/null || true
        muted="$(pactl get-sink-mute "$sink" 2>/dev/null || true)"
        vol="$(pactl get-sink-volume "$sink" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /%$/){sub("%","",$i); print $i; exit}}')"
        kind="audio"
        if [[ "$muted" == *"yes"* ]]; then
            kind="audio-muted"
        fi
        qs ipc -p "$qs_cfg" call -- osd show "$kind" "${vol:-0}" 2>/dev/null || true
    else
        current="$(pactl get-sink-volume "$sink" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /%$/){sub("%","",$i); print $i; exit}}')"
        case "$param" in
            raise) step=5 ;;
            lower) step=-5 ;;
            +*)    step="${param#+}" ;;
            -*)    step="-${param#-}" ;;
            *)     step="${param}" ;;
        esac
        next=$(( ${current:-0} + step ))
        (( next <= 100 )) || next=100
        (( next >= 0 )) || next=0
        pactl set-sink-mute "$sink" 0 2>/dev/null || true
        pactl set-sink-volume "$sink" "${next}%" 2>/dev/null || true
        qs ipc -p "$qs_cfg" call -- osd show "audio" "$next" 2>/dev/null || true
    fi
elif [[ "$action" == "brightness" ]]; then
    omarchy-brightness-display --no-osd "$param"
    bri="$(brightnessctl -m 2>/dev/null | awk -F, '{gsub("%","",$4); print $4; exit}')"
    qs ipc -p "$qs_cfg" call -- osd show "brightness" "${bri:-0}" 2>/dev/null || true
fi
