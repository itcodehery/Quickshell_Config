#!/usr/bin/env bash
# System task monitor: checks for package managers or system maintenance operations
set -u

task_active=0
label=""

if pgrep -x pacman >/dev/null 2>&1 || [ -f /var/lib/pacman/db.lck ]; then
  task_active=1
  label="System update (pacman)"
elif pgrep -x yay >/dev/null 2>&1; then
  task_active=1
  label="Package update (yay)"
elif pgrep -x paru >/dev/null 2>&1; then
  task_active=1
  label="Package update (paru)"
elif pgrep -x flatpak >/dev/null 2>&1; then
  task_active=1
  label="Flatpak operation"
fi

printf '{"active":%d,"label":"%s"}\n' "$task_active" "$label"
