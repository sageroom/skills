#!/usr/bin/env bash
# Closes the active shell pane for this agent session and removes tracking files.
set -euo pipefail

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"

source "$(dirname "$0")/_pane-lib.sh"

PANE_ID=$(cat "$PANE_FILE" 2>/dev/null || true)
if [ -n "$PANE_ID" ] && tmux list-panes -t "$PANE_ID" &>/dev/null 2>&1; then
  if is_shell_pane "$PANE_ID"; then
    # Pane is at a shell prompt — safe to offer countdown close.
    tmux send-keys -t "$PANE_ID" "bash ~/.claude/skills/shell-pane/close-countdown.sh && exit" Enter
  fi
  # If an interactive process is running, leave the pane untouched.
fi
rm -f "$PANE_FILE" "$JOB_TMP/shell-pane.done" "$JOB_TMP/shell-pane.log"
