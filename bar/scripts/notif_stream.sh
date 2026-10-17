#!/usr/bin/env bash
# Real-time notification event streamer for Island Notification Peek
set -u

dir1="$HOME/.local/state/omarchy/notifications"
dir2="$HOME/.local/state/omarchy/notifications/history"

mkdir -p "$dir1" "$dir2"

# Watch for closed-for-write or moved-to json files
exec inotifywait -m -q -e close_write,moved_to --format '%w%f' "$dir1" "$dir2" 2>/dev/null | while read -r filepath; do
  case "$filepath" in
    *.json)
      if [ -f "$filepath" ]; then
        # Parse json safely and output as single line
        jq -c '{id: .id, app: .app, summary: .summary, body: .body, appIcon: (if (.appIcon != null and .appIcon != "") then .appIcon elif (.image != null and .image != "") then .image elif (.glyph != null and .glyph != "") then .glyph else "" end), urgency: .urgency}' "$filepath" 2>/dev/null || true
      fi
      ;;
  esac
done
