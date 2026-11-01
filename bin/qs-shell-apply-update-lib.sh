#!/usr/bin/env bash
# Helper library for qs-shell-apply-update.sh (companion rollback & staged smoke checks).

safe_companion_target() {
  local rel="$1" part
  [ -n "$rel" ] || return 1
  [[ "$rel" != /* ]] || return 1
  IFS=/ read -r -a parts <<< "$rel"
  for part in "${parts[@]}"; do
    [ -n "$part" ] || return 1
    [ "$part" != "." ] || return 1
    [ "$part" != ".." ] || return 1
  done
}

trim_line() {
  local s="$1"
  s="${s%%#*}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

backup_companion_targets() {
  local targets="$1" raw rel src dst
  [ -f "$targets" ] || return 0
  companion_backup="$(mktemp -d -p "$STATE_DIR" companion-targets.XXXXXX)" || \
    fail "Could not create companion rollback backup."
  companion_backup_manifest="$companion_backup/manifest"
  : > "$companion_backup_manifest" || fail "Could not create companion rollback manifest."

  while IFS= read -r raw || [ -n "$raw" ]; do
    rel="$(trim_line "$raw")"
    [ -n "$rel" ] || continue
    safe_companion_target "$rel" || fail "Unsafe companion rollback target '$rel'."
    src="$HOME/$rel"
    dst="$companion_backup/root/$rel"
    if [ -e "$src" ] || [ -L "$src" ]; then
      mkdir -p "$(dirname "$dst")" || fail "Could not back up companion target '$rel'."
      cp -a "$src" "$dst" || fail "Could not back up companion target '$rel'."
      printf 'present\t%s\n' "$rel" >> "$companion_backup_manifest"
    else
      printf 'missing\t%s\n' "$rel" >> "$companion_backup_manifest"
    fi
  done < "$targets"
}

restore_companion_targets() {
  local status rel dst src rc=0
  [ -n "${companion_backup_manifest:-}" ] || return 0
  [ -f "$companion_backup_manifest" ] || return 0

  while IFS=$'\t' read -r status rel || [ -n "$status$rel" ]; do
    [ -n "$rel" ] || continue
    safe_companion_target "$rel" || continue
    dst="$HOME/$rel"
    src="$companion_backup/root/$rel"
    rm -rf "$dst" 2>/dev/null || rc=1
    if [ "$status" = "present" ] && { [ -e "$src" ] || [ -L "$src" ]; }; then
      mkdir -p "$(dirname "$dst")" 2>/dev/null || rc=1
      cp -a "$src" "$dst" 2>/dev/null || rc=1
    fi
  done < "$companion_backup_manifest"
  return "$rc"
}

companion_systemd_units=(
  qs-aur-blacklist-fetch.timer
  qs-shell-update-check.timer
  opencode-usage.timer
)

snapshot_companion_systemd() {
  local unit enabled active
  command -v systemctl >/dev/null 2>&1 || return 0
  [ -n "${companion_backup:-}" ] || return 0
  companion_systemd_snapshot="$companion_backup/systemd-state"
  : > "$companion_systemd_snapshot" || fail "Could not snapshot companion systemd state."
  for unit in "${companion_systemd_units[@]}"; do
    enabled="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
    active="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
    printf '%s\t%s\t%s\n' "$unit" "${enabled:-unknown}" "${active:-unknown}" >> "$companion_systemd_snapshot"
  done
}

restore_companion_systemd() {
  local unit enabled active rc=0
  [ -n "${companion_systemd_snapshot:-}" ] || return 0
  [ -f "$companion_systemd_snapshot" ] || return 0
  command -v systemctl >/dev/null 2>&1 || return 0

  systemctl --user daemon-reload >/dev/null 2>&1 || rc=1
  while IFS=$'\t' read -r unit enabled active || [ -n "$unit$enabled$active" ]; do
    [ -n "$unit" ] || continue
    case "$enabled" in
      enabled|enabled-runtime|linked|linked-runtime)
        systemctl --user enable "$unit" >/dev/null 2>&1 || rc=1
        ;;
      disabled|disabled-runtime|masked|masked-runtime|bad|not-found)
        systemctl --user disable "$unit" >/dev/null 2>&1 || rc=1
        ;;
    esac
    case "$active" in
      active|activating|reloading)
        systemctl --user start "$unit" >/dev/null 2>&1 || rc=1
        ;;
      inactive|failed|deactivating)
        systemctl --user stop "$unit" >/dev/null 2>&1 || rc=1
        ;;
    esac
  done < "$companion_systemd_snapshot"
  systemctl --user daemon-reload >/dev/null 2>&1 || rc=1
  return "$rc"
}

commit_companion_systemd() {
  local units="$HOME/.config/systemd/user" unit rc=0
  local changed_units=()
  command -v systemctl >/dev/null 2>&1 || return 0

  for unit in "${companion_systemd_units[@]}"; do
    if [ -f "$units/$unit" ]; then
      changed_units+=("$unit")
    fi
  done
  if [ "${#changed_units[@]}" -gt 0 ]; then
    systemctl --user daemon-reload >/dev/null 2>&1 || rc=1
    for unit in "${changed_units[@]}"; do
      systemctl --user enable --now "$unit" >/dev/null 2>&1 || rc=1
    done
    systemctl --user try-restart "${changed_units[@]}" >/dev/null 2>&1 || rc=1
  fi
  return "$rc"
}

check_stage_imports() {
  local root="$1" file dir line rel path rc=0
  while IFS= read -r -d '' file; do
    dir="$(dirname "$file")"
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" =~ ^[[:space:]]*import[[:space:]]*\"([^\"]+)\" ]]; then
        rel="${BASH_REMATCH[1]}"
        case "$rel" in
          :*|qrc:*) ;;
          *) [ -e "$dir/$rel" ] || rc=1 ;;
        esac
      fi

      if [[ "$line" =~ ^[[:space:]]*import[[:space:]]+qs\.([A-Za-z0-9_.]+) ]]; then
        rel="${BASH_REMATCH[1]}"
        path="${rel//./\/}"
        [ -d "$root/$path" ] || rc=1
        [ -f "$root/$path/qmldir" ] || rc=1
      fi
    done < "$file"
  done < <(find "$root" -name '*.qml' -type f -print0)
  return "$rc"
}

run_quickshell_smoke() {
  local qs_bin="$1" wrapper="$2" timeout_s="$3" platform="$4" out="$5" err="$6" rc=0
  if [ -n "$platform" ]; then
    QT_QPA_PLATFORM="$platform" timeout "$timeout_s" "$qs_bin" -p "$wrapper" --no-duplicate --no-color >"$out" 2>"$err" || rc=$?
  else
    timeout "$timeout_s" "$qs_bin" -p "$wrapper" --no-duplicate --no-color >"$out" 2>"$err" || rc=$?
  fi
  [ "$rc" -eq 0 ] || return 1
  grep -Fq "QS_SHELL_SMOKE_OK" "$out" "$err" 2>/dev/null || return 1
  ! grep -Fq "QS_SHELL_SMOKE_FAIL" "$out" "$err" 2>/dev/null
}

smoke_stage() {
  local root="$1" smoke out err qs_bin smoke_timeout smoke_platform wrapper target_url root_wrapper
  [ -f "$root/shell.qml" ] || fail "Staged version '$ver' is missing shell.qml."
  qs_bin="${QS_SHELL_QUICKSHELL_BIN:-}"
  if [ -z "$qs_bin" ]; then
    qs_bin="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null || true)"
  fi
  [ -n "$qs_bin" ] || fail "quickshell is required for staged shell smoke."
  command -v timeout >/dev/null 2>&1 || fail "timeout is required for staged shell smoke."
  check_stage_imports "$root" || fail "Staged shell contains unresolved local or qs.* QML imports."

  smoke="$(mktemp -d -p "$STATE_DIR" smoke.XXXXXX)" || fail "Could not create staged shell smoke directory."
  wrapper="$smoke/file-url-smoke.qml"
  target_url="file://$root/shell.qml"
  target_url="${target_url//\\/\\\\}"
  target_url="${target_url//\"/\\\"}"
  cat > "$wrapper" <<'QML'
import QtQuick

QtObject {
  id: root
  property var component: null
  property bool finished: false

  function finish(ok, errorText) {
    if (finished)
      return
    finished = true
    if (ok)
      console.log("QS_SHELL_SMOKE_OK")
    else
      console.error("QS_SHELL_SMOKE_FAIL " + errorText)
    Qt.callLater(Qt.quit)
  }

  function evaluateStatus() {
    if (component.status === Component.Ready)
      finish(true, "")
    else if (component.status === Component.Error)
      finish(false, component.errorString())
  }

  Component.onCompleted: {
    component = Qt.createComponent("__QS_SHELL_TARGET_URL__")
    if (component.status === Component.Loading)
      component.statusChanged.connect(function() { root.evaluateStatus() })
    root.evaluateStatus()
  }
}
QML
  sed -i "s|__QS_SHELL_TARGET_URL__|$target_url|" "$wrapper" || {
    rm -rf "$smoke"
    fail "Could not prepare staged shell smoke wrapper."
  }
  out="$smoke/file-url.out"
  err="$smoke/file-url.err"
  smoke_timeout="${QS_SHELL_SMOKE_TIMEOUT:-3}"
  smoke_platform="${QS_SHELL_SMOKE_PLATFORM:-}"
  if run_quickshell_smoke "$qs_bin" "$wrapper" "$smoke_timeout" "$smoke_platform" "$out" "$err"; then
    rm -rf "$smoke"
    return 0
  fi

  # Fallback for staged qs.* modules. The wrapper must live in the staged root
  # so that root-relative module resolution can see <root>/modules/qmldir, but
  # it must only load the component. Do not start the staged shell as a real
  # Quickshell entry point and do not call createObject(): both can execute
  # PanelWindow, Process, IPC and cache-writing side effects before the swap.
  root_wrapper="$root/.qs-shell-smoke.qml"
  cat > "$wrapper" <<'QML'
import QtQuick

QtObject {
  id: root
  property var component: null
  property bool finished: false

  function finish(ok, errorText) {
    if (finished)
      return
    finished = true
    if (ok)
      console.log("QS_SHELL_SMOKE_OK")
    else
      console.error("QS_SHELL_SMOKE_FAIL " + errorText)
    Qt.callLater(Qt.quit)
  }

  function evaluateStatus() {
    if (component.status === Component.Ready)
      finish(true, "")
    else if (component.status === Component.Error)
      finish(false, component.errorString())
  }

  Component.onCompleted: {
    component = Qt.createComponent(Qt.resolvedUrl("shell.qml"))
    if (component.status === Component.Loading)
      component.statusChanged.connect(function() { root.evaluateStatus() })
    root.evaluateStatus()
  }
}
QML
  mv "$wrapper" "$root_wrapper" || {
    rm -rf "$smoke"
    fail "Could not prepare staged shell root smoke wrapper."
  }
  out="$smoke/root.out"
  err="$smoke/root.err"
  if run_quickshell_smoke "$qs_bin" "$root_wrapper" "$smoke_timeout" "$smoke_platform" "$out" "$err"; then
    rm -f "$root_wrapper" || { rm -rf "$smoke"; fail "Could not clean staged shell smoke wrapper."; }
    rm -rf "$smoke"
    return 0
  fi
  rm -f "$root_wrapper"
  rm -rf "$smoke"
  fail "Staged shell Quickshell smoke failed."
}

smoke_integrated_variants() {
  local root="$1" smoke wrapper out err qs_bin smoke_timeout smoke_platform detail

  [ -f "$root/VariantRoot.qml" ] || fail "Integrated payload is missing the V1 VariantRoot."
  [ -f "$root/variants/V2/VariantRoot.qml" ] || fail "Integrated payload is missing the V2 VariantRoot."
  [ -x "$root/core/qs-system-update.sh" ] || \
    fail "Integrated payload is missing the executable system-update adapter."
  qs_bin="${QS_SHELL_QUICKSHELL_BIN:-}"
  if [ -z "$qs_bin" ]; then
    qs_bin="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null || true)"
  fi
  [ -n "$qs_bin" ] || fail "quickshell is required for integrated variant smoke."

  smoke="$(mktemp -d -p "$STATE_DIR" variant-smoke.XXXXXX)" || \
    fail "Could not create integrated variant smoke directory."
  wrapper="$root/.qs-variant-smoke.qml"
  cat > "$wrapper" <<'QML'
import QtQuick
// Register the complete lazy V2 type graph with Quickshell's VFS scanner.
import "variants/V2" as V2Bundle

QtObject {
  id: root
  property var v1Component: null
  property var v2Component: null
  property bool finished: false

  function finish(ok, errorText) {
    if (finished)
      return
    finished = true
    if (ok)
      console.log("QS_SHELL_SMOKE_OK")
    else
      console.error("QS_SHELL_SMOKE_FAIL " + errorText)
    Qt.callLater(Qt.quit)
  }

  function evaluateStatus() {
    if (v1Component === null || v2Component === null)
      return
    if (v1Component.status === Component.Error) {
      finish(false, "V1: " + v1Component.errorString())
      return
    }
    if (v2Component.status === Component.Error) {
      finish(false, "V2: " + v2Component.errorString())
      return
    }
    if (v1Component.status === Component.Ready
        && v2Component.status === Component.Ready)
      finish(true, "")
  }

  Component.onCompleted: {
    v1Component = Qt.createComponent(Qt.resolvedUrl("VariantRoot.qml"))
    v2Component = Qt.createComponent(Qt.resolvedUrl("variants/V2/VariantRoot.qml"))
    if (v1Component.status === Component.Loading)
      v1Component.statusChanged.connect(function() { root.evaluateStatus() })
    if (v2Component.status === Component.Loading)
      v2Component.statusChanged.connect(function() { root.evaluateStatus() })
    evaluateStatus()
  }
}
QML
  out="$smoke/out"
  err="$smoke/err"
  smoke_timeout="${QS_SHELL_SMOKE_TIMEOUT:-3}"
  smoke_platform="${QS_SHELL_SMOKE_PLATFORM:-}"
  if run_quickshell_smoke "$qs_bin" "$wrapper" "$smoke_timeout" "$smoke_platform" "$out" "$err"; then
    rm -f "$wrapper"
    rm -rf "$smoke"
    return 0
  fi
  detail="$(grep -h -F -m1 "QS_SHELL_SMOKE_FAIL " "$out" 2>/dev/null || true)"
  if [ -z "$detail" ]; then
    detail="$(grep -h -F -m1 "QS_SHELL_SMOKE_FAIL " "$err" 2>/dev/null || true)"
  fi
  detail="${detail#*QS_SHELL_SMOKE_FAIL }"
  if [ "${#detail}" -gt 600 ]; then
    detail="${detail:0:597}..."
  fi
  rm -f "$wrapper"
  rm -rf "$smoke"
  if [ -n "$detail" ]; then
    fail "Integrated V1/V2 variant smoke failed: $detail"
  fi
  fail "Integrated V1/V2 variant smoke failed."
}
