#!/usr/bin/env bash
# QS theme-update APPLY — install only commits recorded by qs-theme-update-check.
# No moving git pull target: the theme must still be on the scanned base commit,
# the remote identity/upstream must match, and the saved target commit must still
# be reachable from the expected remote-tracking ref after fetch.
set -euo pipefail

THEMES_DIR="${QS_THEMES_DIR:-$HOME/.config/omarchy/themes}"
STATE="${QS_THEME_STATE:-$HOME/.cache/qs-theme-updates.json}"
LOCK="${QS_THEME_LOCK:-$HOME/.cache/qs-theme-update.lock}"
FETCH_TIMEOUT="${QS_THEME_FETCH_TIMEOUT:-45}"

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true
export SSH_ASKPASS=/bin/true
export GIT_SSH_COMMAND="ssh -oBatchMode=yes -oConnectTimeout=8"
export GIT_CONFIG_NOSYSTEM=1

usage() {
  printf 'Usage: %s --all | <theme> [theme...]\n' "${0##*/}" >&2
}

valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

valid_commit() {
  [[ "$1" =~ ^[0-9A-Fa-f]{40}$ || "$1" =~ ^[0-9A-Fa-f]{64}$ ]]
}

valid_ref() {
  git check-ref-format "$1" >/dev/null 2>&1
}

entry_field() {
  jq -er --arg key "$2" '.[$key] // empty' "$1"
}

fail_theme() {
  printf 'ERROR %s: %s\n' "$1" "$2" >&2
  return 1
}

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

apply_theme() {
  local name="$1"
  valid_name "$name" || { fail_theme "$name" "invalid theme name"; return 1; }

  local entry_file
  entry_file="$(mktemp)"
  jq -cer --arg name "$name" '.themes[] | select(.name == $name)' "$STATE_SNAPSHOT" > "$entry_file" \
    || { rm -f "$entry_file"; fail_theme "$name" "not present in current theme-update state"; return 1; }

  local state behind head remote remote_url upstream_ref tracking_ref base_commit target_commit
  state="$(entry_field "$entry_file" state)"
  behind="$(entry_field "$entry_file" behind)"
  head="$(entry_field "$entry_file" head)"
  remote="$(entry_field "$entry_file" remote)"
  remote_url="$(entry_field "$entry_file" remoteUrl)"
  upstream_ref="$(entry_field "$entry_file" upstreamRef)"
  tracking_ref="$(entry_field "$entry_file" trackingRef)"
  base_commit="$(entry_field "$entry_file" baseCommit)"
  target_commit="$(entry_field "$entry_file" targetCommit)"
  rm -f "$entry_file"

  [ "$state" = "clean" ] || { fail_theme "$name" "state is '$state', not clean"; return 1; }
  [ "${behind:-0}" -gt 0 ] || { fail_theme "$name" "state has no pending commits"; return 1; }
  valid_ref "refs/heads/$head" || { fail_theme "$name" "invalid saved branch"; return 1; }
  [ -n "$remote" ] || { fail_theme "$name" "missing saved remote"; return 1; }
  [ -n "$remote_url" ] || { fail_theme "$name" "missing saved remote URL"; return 1; }
  valid_ref "$upstream_ref" || { fail_theme "$name" "invalid saved upstream ref"; return 1; }
  valid_ref "$tracking_ref" || { fail_theme "$name" "invalid saved tracking ref"; return 1; }
  valid_commit "$base_commit" || { fail_theme "$name" "invalid saved base commit"; return 1; }
  valid_commit "$target_commit" || { fail_theme "$name" "invalid saved target commit"; return 1; }

  local dir="$THEMES_DIR/$name"
  [ -d "$dir/.git" ] || { fail_theme "$name" "theme git repo not found"; return 1; }

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

  local current_head current_remote current_upstream current_url current_commit
  current_head="$("${tg[@]}" symbolic-ref --quiet --short HEAD 2>/dev/null)" \
    || { fail_theme "$name" "not on a branch"; return 1; }
  current_remote="$("${tg[@]}" config "branch.$current_head.remote" 2>/dev/null)" \
    || { fail_theme "$name" "branch has no remote"; return 1; }
  current_upstream="$("${tg[@]}" config "branch.$current_head.merge" 2>/dev/null)" \
    || { fail_theme "$name" "branch has no upstream"; return 1; }
  current_url="$("${tg[@]}" remote get-url "$current_remote" 2>/dev/null)" \
    || { fail_theme "$name" "remote URL unavailable"; return 1; }
  current_commit="$("${tg[@]}" rev-parse HEAD 2>/dev/null)" \
    || { fail_theme "$name" "HEAD unavailable"; return 1; }

  [ "$current_head" = "$head" ] || { fail_theme "$name" "branch changed since check"; return 1; }
  [ "$current_remote" = "$remote" ] || { fail_theme "$name" "remote changed since check"; return 1; }
  [ "$current_upstream" = "$upstream_ref" ] || { fail_theme "$name" "upstream changed since check"; return 1; }
  [ "$current_url" = "$remote_url" ] || { fail_theme "$name" "remote URL changed since check"; return 1; }
  [ "$current_commit" = "$base_commit" ] || { fail_theme "$name" "HEAD changed since check"; return 1; }

  local branch="${upstream_ref#refs/heads/}"
  [ "$branch" != "$upstream_ref" ] || { fail_theme "$name" "upstream is not a branch ref"; return 1; }
  [ "$tracking_ref" = "refs/remotes/$remote/$branch" ] \
    || { fail_theme "$name" "tracking ref does not match saved remote/upstream"; return 1; }

  printf '\n==> Updating theme: %s\n' "$name"
  timeout "$FETCH_TIMEOUT" "${tg[@]}" fetch --quiet -- "$remote" "$upstream_ref:$tracking_ref" \
    || { fail_theme "$name" "fetch failed"; return 1; }

  "${tg[@]}" cat-file -e "$target_commit^{commit}" 2>/dev/null \
    || { fail_theme "$name" "target commit is not available after fetch"; return 1; }
  "${tg[@]}" merge-base --is-ancestor "$target_commit" "$tracking_ref" \
    || { fail_theme "$name" "target commit is no longer reachable from upstream"; return 1; }
  "${tg[@]}" merge-base --is-ancestor HEAD "$target_commit" \
    || { fail_theme "$name" "target is not a fast-forward from current HEAD"; return 1; }

  local tmp collisions tracked_dirty
  tmp="$(mktemp -d)"
  "${tg[@]}" diff -z --name-only --diff-filter=ACMRT "HEAD..$target_commit" 2>/dev/null > "$tmp/incoming.z" \
    || : > "$tmp/incoming.z"
  # Deliberately no --exclude-standard: ignored untracked files are still local
  # data, and git can silently overwrite them when an incoming commit starts
  # tracking the same path, or a file/directory prefix of that path.
  "${tg[@]}" ls-files -z --others 2>/dev/null > "$tmp/untracked.z" \
    || : > "$tmp/untracked.z"
  collisions="$(path_collision_sample "$tmp/incoming.z" "$tmp/untracked.z")"
  if [ -n "$collisions" ]; then
    rm -rf "$tmp"
    fail_theme "$name" "untracked file would be overwritten: $(printf '%s' "$collisions" | tr '\n' ' ')"
    return 1
  fi

  tracked_dirty="$("${tg[@]}" status --porcelain 2>/dev/null | grep -cv '^??\|^$' || true)"
  if [ "${tracked_dirty:-0}" -ne 0 ]; then
    rm -rf "$tmp"
    fail_theme "$name" "working tree has tracked edits"
    return 1
  fi

  if ! "${tg[@]}" merge --ff-only "$target_commit"; then
    rm -rf "$tmp"
    fail_theme "$name" "fast-forward failed"
    return 1
  fi
  rm -rf "$tmp"
  printf 'Installed %s at %s\n' "$name" "$target_commit"
  return 0
}

command -v jq >/dev/null 2>&1 || { printf 'jq is not installed.\n' >&2; exit 127; }
command -v git >/dev/null 2>&1 || { printf 'git is not installed.\n' >&2; exit 127; }
[ -r "$STATE" ] || { printf 'Theme-update state not found: %s\n' "$STATE" >&2; exit 1; }

mkdir -p "$(dirname "$LOCK")"
exec 9>"$LOCK"
if ! flock -n 9; then
  printf 'Theme-update state is busy; retry after the current check/apply finishes.\n' >&2
  exit 75
fi

STATE_SNAPSHOT="$(mktemp)"
trap 'rm -f "$STATE_SNAPSHOT"' EXIT
if ! jq -c . "$STATE" > "$STATE_SNAPSHOT"; then
  printf 'Theme-update state is invalid: %s\n' "$STATE" >&2
  exit 1
fi

themes=()
if [ "${1:-}" = "--all" ]; then
  mapfile -t themes < <(jq -r '.themes[] | select(.state == "clean" and (.behind | tonumber) > 0) | .name' "$STATE_SNAPSHOT")
elif [ "$#" -gt 0 ]; then
  themes=("$@")
else
  usage
  exit 64
fi

[ "${#themes[@]}" -gt 0 ] || { printf 'No clean theme updates in current state.\n'; exit 0; }

ok=0
fail=0
for theme in "${themes[@]}"; do
  if apply_theme "$theme"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
done

printf '\nTheme update apply finished: %d ok, %d failed\n' "$ok" "$fail"
[ "$fail" -eq 0 ]
