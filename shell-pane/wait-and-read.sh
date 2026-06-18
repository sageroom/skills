#!/usr/bin/env bash
# Waits for the active pane script to finish, then prints its output.
# Usage: wait-and-read.sh [timeout_seconds]  (default: 120)
# On timeout, captures and prints the pane contents so a command that was typed
# into the wrong/busy process (never executed) is visible, not a bare TIMEOUT.
set -euo pipefail

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"
DONE_FILE="$JOB_TMP/shell-pane.done"
LOG_FILE="$JOB_TMP/shell-pane.log"
TIMEOUT="${1:-120}"

deadline=$(( $(date +%s) + TIMEOUT ))
while [ ! -f "$DONE_FILE" ]; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "TIMEOUT: pane did not finish within ${TIMEOUT}s" >&2
    PANE_ID=$(cat "$PANE_FILE" 2>/dev/null || true)
    if [ -n "$PANE_ID" ] && tmux list-panes -t "$PANE_ID" &>/dev/null 2>&1; then
      echo "--- pane contents at timeout ($PANE_ID) ---" >&2
      tmux capture-pane -p -t "$PANE_ID" >&2 || true
      echo "--- end pane contents ---" >&2
      echo "If this shows a shell prompt or an unrelated running process, the command was never executed (e.g. typed into a busy pane)." >&2
    else
      echo "(no live pane to capture — marker missing or pane gone)" >&2
    fi
    exit 1
  fi
  sleep 1
done

cat "$LOG_FILE"
