#!/usr/bin/env bash
# Shared helpers for the shell-pane skill.
# Sourced by run-remote.sh, run-local.sh, probe-remote.sh, and close-pane.sh.
#
# Provides:
#   is_shell_pane PANE_ID   -> 0 if the pane is sitting at a shell prompt
#   ensure_shell_pane       -> echoes a live shell PANE_ID, opening a fresh
#                              pane (and repointing the marker) if the tracked
#                              one is missing, dead, or busy.
#
# Detection is shared by every caller. The *policy* for a busy pane differs:
# close-pane.sh leaves it untouched (protecting a running process), while the
# runners open a fresh pane via ensure_shell_pane. Never kill a busy pane here.

# PANE_FILE may already be set by the caller; default it for standalone use.
: "${PANE_FILE:=${CLAUDE_JOB_DIR}/tmp/shell-pane-active}"

# Return 0 if the pane is sitting at an interactive shell prompt (safe to send
# keystrokes to), 1 if it is running anything in the foreground.
#
# Two gates, both required:
#   1. pane_current_command is a shell name (bash/zsh/sh/fish/dash) — the
#      original close-pane.sh check.
#   2. the pane's shell has no foreground child. Gate 1 alone is not enough:
#      while the helpers' own `bash $SCRIPT | tee` pipeline runs, tmux reports
#      the foreground command as `bash`, which would pass gate 1. The no-child
#      test catches that (and any TUI/server) regardless of how it is named.
is_shell_pane() {
  local pane_id="$1"
  [ -n "$pane_id" ] || return 1

  local current_cmd shell_pid s matched=false
  current_cmd=$(tmux display-message -t "$pane_id" -p '#{pane_current_command}' 2>/dev/null || true)
  for s in bash zsh sh fish dash; do
    [ "$current_cmd" = "$s" ] && { matched=true; break; }
  done
  $matched || return 1

  # A foreground child means the shell is running something, not idle at a prompt.
  shell_pid=$(tmux display-message -t "$pane_id" -p '#{pane_pid}' 2>/dev/null || true)
  if [ -n "$shell_pid" ] && pgrep -P "$shell_pid" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Echo a usable PANE_ID for dispatch. Reuses the tracked pane only when it is
# alive AND at a shell; otherwise opens a fresh pane and repoints the marker.
# A busy tracked pane is left running and simply abandoned (not killed).
ensure_shell_pane() {
  local pane_id
  pane_id=$(cat "$PANE_FILE" 2>/dev/null || true)

  if [ -n "$pane_id" ] \
    && tmux list-panes -t "$pane_id" &>/dev/null 2>&1 \
    && is_shell_pane "$pane_id"; then
    echo "$pane_id"
    return 0
  fi

  # Missing, dead, or busy -> open a fresh pane and track it. Capture the new
  # pane id directly from split-window (-P -F) — `list-panes | tail -1` is wrong
  # when other panes exist, because splitting main:0.0 renumbers pane indices.
  pane_id=$(tmux split-window -h -d -P -F '#{pane_id}' -t main:0.0)
  echo "$pane_id" > "$PANE_FILE"
  echo "$pane_id"
}
