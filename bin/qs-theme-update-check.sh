#!/usr/bin/env bash
# QS theme-update CHECK — read-only scan for the in-bar theme updater. Omarchy has
# no "which themes are outdated" signal; this provides it for the bar badge/panel
# and records the exact commits a later apply step is allowed to fast-forward to.
#
# Scope of THIS script: NO working-tree change, NO branch/HEAD change, NO commit.
# It DOES `git fetch` themes whose remote moved (updates refs/remotes/* + downloads
# objects into .git) to compute the behind-count — a normal local git write for an
# update check, just not to your files. The only file it writes is the state JSON.
#
# Two-stage remote probe per theme, cheapest first:
#   1. `git ls-remote` on the tracked branch — pure network read. Equal to the
#      local remote-tracking ref => nothing moved, no fetch.
#   2. `git fetch` only when the remote moved (needed for the behind-count).
#
# Neutral per-theme state:
#   clean        reachable, behind>0, no local tracked edits and no untracked file
#                that an incoming tracked file would overwrite
#   local-edits  reachable, behind>0, has tracked modifications or local commits
#                or an untracked overwrite collision (git pull may merge/conflict
#                or abort — the user sees it in the terminal)
#   unreachable  the remote could not be reached
#   (up-to-date and no-upstream themes are simply not listed)
#
# State contract (same as qs-shell-check-update.sh): the JSON always exists once
# written, writes are atomic (mktemp+mv), the file is never deleted, and a run
# that reached NO remote leaves the last good state untouched. degraded:true means
# the sweep was cut short — counts are lower bounds, never a fake "all up to date".
#
# Env overrides (sandbox tests use these):
#   QS_THEMES_DIR   themes root      (default ~/.config/omarchy/themes)
#   QS_THEME_STATE  state json path  (default ~/.cache/qs-theme-updates.json)
#   QS_THEME_LOCK   lock file path   (default ~/.cache/qs-theme-update.lock)
#   QS_CURRENT_FILE current theme.name path
#   QS_THEME_TIMEOUT        ls-remote, seconds (default 10)
#   QS_THEME_FETCH_TIMEOUT  fetch, seconds     (default 45 — image-heavy themes
#                           measured 8-13.5s; 10s misclassified them unreachable)
#   QS_THEME_BUDGET         whole sweep, seconds (default 180)
#   QS_THEME_JOBS           parallel workers     (default 4)
set -euo pipefail

THEMES_DIR="${QS_THEMES_DIR:-$HOME/.config/omarchy/themes}"
STATE="${QS_THEME_STATE:-$HOME/.cache/qs-theme-updates.json}"
LOCK="${QS_THEME_LOCK:-$HOME/.cache/qs-theme-update.lock}"
if [ -n "${QS_CURRENT_FILE:-}" ]; then
  CURRENT_FILE="$QS_CURRENT_FILE"
elif command -v omarchy-shell >/dev/null 2>&1 && [ -f "$HOME/.local/state/omarchy/current/theme.name" ]; then
  CURRENT_FILE="$HOME/.local/state/omarchy/current/theme.name"
else
  CURRENT_FILE="$HOME/.config/omarchy/current/theme.name"
fi
NET_TIMEOUT="${QS_THEME_TIMEOUT:-10}"
FETCH_TIMEOUT="${QS_THEME_FETCH_TIMEOUT:-45}"
BUDGET="${QS_THEME_BUDGET:-180}"
JOBS="${QS_THEME_JOBS:-4}"

command -v jq >/dev/null 2>&1 || {
  notify-send -a "QS-Shell" "Theme update check disabled" "jq is not installed." 2>/dev/null || true
  exit 0
}
command -v git >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$STATE")"

# Never prompt, never hang on credentials: broken/private remotes become
# unreachable instead of blocking a worker until the budget kills it.
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true
export SSH_ASKPASS=/bin/true
export GIT_SSH_COMMAND="ssh -oBatchMode=yes -oConnectTimeout=8"
export GIT_CONFIG_NOSYSTEM=1

# Single-flight, shared with any concurrent check.
exec 9>"$LOCK"
flock -n 9 || exit 0

CURRENT_THEME=""
[ -r "$CURRENT_FILE" ] && CURRENT_THEME="$(tr -d '[:space:]' < "$CURRENT_FILE" 2>/dev/null || true)"

path_is_or_under() { # path prefix
  local path="$1" prefix="$2"
  [ "$path" = "$prefix" ] && return 0
  [ -n "$prefix" ] || return 1
  [ "${path:0:${#prefix}}" = "$prefix" ] && [ "${path:${#prefix}:1}" = "/" ]
}

path_collision_sample() { # incoming-z local-untracked-z
  local incoming_file="$1" local_file="$2"
  local -a incoming_paths=() local_paths=()
  local incoming local_path count=0
  local -A seen=()
  mapfile -d '' -t incoming_paths < "$incoming_file" || true
  mapfile -d '' -t local_paths < "$local_file" || true

  for incoming in "${incoming_paths[@]}"; do
    [ -n "$incoming" ] || continue
    for local_path in "${local_paths[@]}"; do
      [ -n "$local_path" ] || continue
      if path_is_or_under "$incoming" "$local_path" || path_is_or_under "$local_path" "$incoming"; then
        if [[ -z "${seen[$local_path]+x}" ]]; then
          printf '%q\n' "$local_path"
          seen[$local_path]=1
          count=$((count + 1))
          [ "$count" -ge 5 ] && return 0
        fi
      fi
    done
  done
  return 0
}

# ── per-theme worker ─────────────────────────────────────────────
# Runs in its own bash (no -e inherited); never hangs (every network call under
# `timeout`) and ALWAYS emits exactly one JSON file, even on odd repos.
check_one() {
  local dir="$1" outdir="$2"
  local name; name="$(basename "$dir")"
  local out="$outdir/$name.json"
  local T="${NET_TIMEOUT:-10}"

  # git on an UNTRUSTED theme repo goes through the tg[] prefix: repo-local config
  # that could execute a command is neutralised on the command line (higher
  # precedence than .git/config), so a tampered core.fsmonitor/hooksPath or
  # protocol.* setting can't run code on a mere status/fetch. `--` on the network
  # calls stops a `-`-leading remote/ref value being read as an option. An ARRAY
  # (not a function) so it composes with `timeout`, which execs a real binary and
  # cannot call a shell function.
  local -a tg=(git -C "$dir"
    -c core.fsmonitor=
    -c core.hooksPath=/dev/null
    -c credential.helper=
    -c protocol.allow=never
    -c protocol.ext.allow=never
    -c protocol.file.allow=always
    -c protocol.git.allow=always
    -c protocol.http.allow=always
    -c protocol.https.allow=always
    -c protocol.ssh.allow=always)

  emit() { # emit <state> <behind> [reason] [files-json]
    local reason="${3:-}" files_json="${4:-[]}"
    local target_commit="${remote_sha:-${local_track:-}}"
    jq -n --arg name "$name" --arg state "$1" --argjson behind "$2" \
          --arg reason "$reason" --argjson files "$files_json" \
          --arg head "${head:-}" \
          --arg remote "${remote:-}" \
          --arg remoteUrl "${remote_url:-}" \
          --arg upstreamRef "${merge_ref:-}" \
          --arg trackingRef "${track_ref:-}" \
          --arg baseCommit "${base_commit:-}" \
          --arg targetCommit "$target_commit" \
          --argjson current "$( [ "$name" = "${CURRENT_THEME:-}" ] && echo true || echo false )" \
          '{name:$name, state:$state, behind:$behind, current:$current,
            reason:$reason, files:$files,
            head:$head, remote:$remote, remoteUrl:$remoteUrl,
            upstreamRef:$upstreamRef, trackingRef:$trackingRef,
            baseCommit:$baseCommit, targetCommit:$targetCommit}' > "$out" 2>/dev/null
  }

  # upstream wiring (branch.<head>.remote/.merge). No upstream => not listable.
  local head remote merge_ref rbranch track_ref base_commit remote_url
  head="$("${tg[@]}" symbolic-ref --quiet --short HEAD 2>/dev/null)"    || { emit no-upstream 0; return 0; }
  remote="$("${tg[@]}" config "branch.$head.remote" 2>/dev/null)"       || { emit no-upstream 0; return 0; }
  merge_ref="$("${tg[@]}" config "branch.$head.merge" 2>/dev/null)"     || { emit no-upstream 0; return 0; }
  rbranch="${merge_ref#refs/heads/}"
  track_ref="refs/remotes/$remote/$rbranch"
  "${tg[@]}" rev-parse --verify --quiet "$track_ref" >/dev/null 2>&1    || { emit no-upstream 0; return 0; }
  base_commit="$("${tg[@]}" rev-parse HEAD 2>/dev/null)"                || { emit no-upstream 0; return 0; }
  remote_url="$("${tg[@]}" remote get-url "$remote" 2>/dev/null || true)"

  # stage 1: ls-remote — did the remote move since our last fetch?
  local remote_sha local_track reach="ok"
  remote_sha="$(timeout "$T" "${tg[@]}" ls-remote --quiet -- "$remote" "$merge_ref" 2>/dev/null | awk '{print $1; exit}')" || remote_sha=""
  local_track="$("${tg[@]}" rev-parse "$track_ref" 2>/dev/null)" || local_track=""
  if [ -z "$remote_sha" ]; then
    reach="unreachable"
  elif [ "$remote_sha" != "$local_track" ]; then
    # stage 2: fetch only what moved (objects for the behind-count)
    timeout "${FETCH_TIMEOUT:-45}" "${tg[@]}" fetch --quiet -- "$remote" "$rbranch" >/dev/null 2>&1 || reach="unreachable"
  fi

  local behind ahead tracked_dirty untracked_collision untracked_collision_files tracked_dirty_files reason files_json
  behind="$("${tg[@]}" rev-list --count "HEAD..$track_ref" 2>/dev/null || echo 0)"
  ahead="$("${tg[@]}" rev-list --count "$track_ref..HEAD" 2>/dev/null || echo 0)"
  tracked_dirty="$("${tg[@]}" status --porcelain 2>/dev/null | grep -cv '^??\|^$' || true)"
  "${tg[@]}" diff -z --name-only --diff-filter=ACMRT "HEAD..$track_ref" 2>/dev/null > "$out.incoming.z" || : > "$out.incoming.z"
  # Deliberately no --exclude-standard: ignored untracked files are still local
  # data, and git can silently overwrite them when an incoming commit starts
  # tracking the same path, or a file/directory prefix of that path.
  "${tg[@]}" ls-files -z --others 2>/dev/null > "$out.untracked.z" || : > "$out.untracked.z"
  untracked_collision_files="$(path_collision_sample "$out.incoming.z" "$out.untracked.z")" || untracked_collision_files=""
  untracked_collision="$(printf '%s\n' "$untracked_collision_files" | sed '/^$/d' | head -n 1)" || untracked_collision=""
  tracked_dirty_files="$(
    { "${tg[@]}" diff --name-only 2>/dev/null; "${tg[@]}" diff --cached --name-only 2>/dev/null; } \
      | sort -u | head -n 5
  )" || tracked_dirty_files=""

  if [ "$reach" = "unreachable" ]; then emit unreachable "${behind:-0}"; return 0; fi

  # neutral state: local commits OR tracked modifications => local-edits (a plain
  # git pull may merge/conflict). Any untracked file is also local-edits when the
  # incoming update tracks the same path or a file/directory prefix of it; ignored
  # untracked files are included because git may otherwise overwrite them without
  # the usual warning.
  local state="clean"
  { [ "${ahead:-0}" -gt 0 ] || [ "${tracked_dirty:-0}" -gt 0 ] || [ -n "$untracked_collision" ]; } && state="local-edits"
  reason=""
  files_json="[]"
  if [ "$state" = "local-edits" ]; then
    if [ -n "$untracked_collision" ]; then
      reason="untracked conflict"
      files_json="$(printf '%s\n' "$untracked_collision_files" | sed '/^$/d' | jq -R . | jq -s '.[0:5]' 2>/dev/null)" || files_json="[]"
    elif [ "${tracked_dirty:-0}" -gt 0 ]; then
      reason="tracked edits"
      files_json="$(printf '%s\n' "$tracked_dirty_files" | sed '/^$/d' | jq -R . | jq -s '.[0:5]' 2>/dev/null)" || files_json="[]"
    elif [ "${ahead:-0}" -gt 0 ]; then
      reason="local commits"
    fi
  fi
  emit "$state" "${behind:-0}" "$reason" "$files_json"
  return 0
}
export -f path_is_or_under path_collision_sample check_one
export NET_TIMEOUT FETCH_TIMEOUT CURRENT_THEME

# ── enumerate themes (omarchy detection rule: non-symlink dir with .git) ──
dirs=()
for d in "$THEMES_DIR"/*/; do
  [ -d "$d" ] || continue
  d="${d%/}"
  [ -L "$d" ] && continue
  [ -d "$d/.git" ] || continue
  dirs+=("$d")
done
total=${#dirs[@]}

write_state() { # $1 = complete JSON
  local t
  t="$(mktemp -p "$(dirname "$STATE")" .qs-theme-updates.XXXXXX)" || return 1
  if printf '%s\n' "$1" > "$t" && mv "$t" "$STATE"; then
    return 0
  fi
  rm -f "$t"
  return 1
}

if [ "$total" -eq 0 ]; then
  write_state "$(jq -nc --arg c "$(date -Is)" \
    '{checked:$c,total:0,reachable:0,outdated:0,localEdits:0,degraded:false,currentStale:false,themes:[]}')"
  exit 0
fi

# ── sweep ────────────────────────────────────────────────────────
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rc=0
# shellcheck disable=SC2016
printf '%s\0' "${dirs[@]}" \
  | timeout "$BUDGET" xargs -0 -P "$JOBS" -I{} bash -c 'check_one "$1" "$2"' _ {} "$tmpdir" \
  || rc=$?

# Count only NON-EMPTY result files: a worker killed after opening "$out" but
# before jq wrote leaves a 0-byte file jq -s silently drops — counting it as
# emitted would hide the loss and fake degraded:false.
emitted=$(find "$tmpdir" -name '*.json' -size +0c | wc -l)
degraded=false
{ [ "$rc" -eq 124 ] || [ "$emitted" -lt "$total" ]; } && degraded=true

if [ "$emitted" -eq 0 ]; then
  exit 0                                        # nothing produced — keep last good state
fi

# Offline guard: no remote reachable.
#   - with a prior state: keep it (don't overwrite real data with noise).
#   - first-ever run: don't write a clean-looking {outdated:0} (fresh clones look
#     "up to date"); mark degraded so the panel is honest.
reachable=$(jq -s '[ .[] | select(.state != "unreachable" and .state != "no-upstream") ] | length' "$tmpdir"/*.json)
if [ "$reachable" -eq 0 ]; then
  [ -f "$STATE" ] && exit 0
  degraded=true
fi

state="$(jq -s --arg checked "$(date -Is)" --argjson total "$total" --argjson degraded "$degraded" '
  { checked:   $checked,
    total:     $total,
    reachable: ([ .[] | select(.state != "unreachable" and .state != "no-upstream") ] | length),
    outdated:  ([ .[] | select(.behind > 0) ] | length),
    localEdits:([ .[] | select(.state == "local-edits" and .behind > 0) ] | length),
    degraded:  $degraded,
    currentStale: (([ .[] | select(.current and .behind > 0) ] | length) > 0),
    themes:    ([ .[] | select(.behind > 0 or .state == "unreachable") ]
                | sort_by([(.state == "unreachable" | tostring), (.state == "local-edits" | tostring), .name])
                | map({name, behind, state, current, reason, files,
                       head, remote, remoteUrl, upstreamRef, trackingRef,
                       baseCommit, targetCommit})) }
' "$tmpdir"/*.json)"

write_state "$state"
