#!/usr/bin/env bash
# Verify an interactive/non-terminating command is running in the pane.
# Usage: verify-interactive.sh [sleep_seconds]  (default: 3)
# Prints the captured pane content so Claude can confirm the TUI is visible.
set -euo pipefail

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"
SLEEP_SECS="${1:-3}"

PANE_ID=$(cat "$PANE_FILE" 2>/dev/null || true)
if [ -z "$PANE_ID" ]; then
  echo "ERROR: no active pane found (shell-pane-active not set)" >&2
  exit 1
fi

sleep "$SLEEP_SECS"
tmux capture-pane -p -t "$PANE_ID"
