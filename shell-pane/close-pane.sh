#!/usr/bin/env bash
# Closes the active shell pane for this agent session and removes tracking files.
set -euo pipefail

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"

PANE_ID=$(cat "$PANE_FILE" 2>/dev/null || true)
if [ -n "$PANE_ID" ] && tmux list-panes -t "$PANE_ID" &>/dev/null 2>&1; then
  # Run countdown in the pane — exits the shell (closes pane) on timeout,
  # or returns 1 (keeps pane open) if user presses a key.
  tmux send-keys -t "$PANE_ID" "bash ~/.claude/skills/shell-pane/close-countdown.sh && exit" Enter
  # Only remove tracking if we're not keeping the pane open.
  # If the user intervenes, the pane stays but tracking is cleared so
  # the next task opens a fresh pane alongside it.
fi
rm -f "$PANE_FILE" "$JOB_TMP/shell-pane.done" "$JOB_TMP/shell-pane.log"
