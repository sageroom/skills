#!/usr/bin/env bash
# Waits for the active pane script to finish, then prints its output.
# Usage: wait-and-read.sh [timeout_seconds]  (default: 120)
set -euo pipefail

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
DONE_FILE="$JOB_TMP/shell-pane.done"
LOG_FILE="$JOB_TMP/shell-pane.log"
TIMEOUT="${1:-120}"

deadline=$(( $(date +%s) + TIMEOUT ))
while [ ! -f "$DONE_FILE" ]; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "TIMEOUT: pane did not finish within ${TIMEOUT}s" >&2
    exit 1
  fi
  sleep 1
done

cat "$LOG_FILE"
