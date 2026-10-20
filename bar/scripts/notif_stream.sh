#!/usr/bin/env bash
# Real-time notification event streamer for Island Notification Peek
set -u

dir1="$HOME/.local/state/omarchy/notifications"
mkdir -p "$dir1"

# Monitor dir1 for additions (close_write, moved_to) and dismissals (moved_from, delete)
exec inotifywait -m -q -e close_write,moved_to,delete,moved_from --format '%w|%e|%f' "$dir1" 2>/dev/null | while IFS='|' read -r wpath event file; do
  case "$file" in
    *.json)
      case "$event" in
        *CLOSE_WRITE*|*MOVED_TO*)
          filepath="${wpath}${file}"
          if [ -f "$filepath" ]; then
            # Parse json safely and output as single line with event: "new"
            jq -c '{event: "new", id: .id, app: .app, summary: .summary, body: .body, appIcon: (if (.appIcon != null and .appIcon != "") then .appIcon elif (.image != null and .image != "") then .image elif (.glyph != null and .glyph != "") then .glyph else "" end), urgency: .urgency}' "$filepath" 2>/dev/null || true
          fi
          ;;
        *MOVED_FROM*|*DELETE*)
          # Extract ID if available from timestamp-id.json
          raw_stem="${file%.json}"
          notif_id="${raw_stem##*-}"
          echo "{\"event\":\"dismiss\",\"id\":${notif_id:-0}}"
          ;;
      esac
      ;;
  esac
done
