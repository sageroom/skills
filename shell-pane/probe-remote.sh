#!/usr/bin/env bash
# Usage: probe-remote.sh HOST "single read-only command"
# Thin visible read-only probe: runs one SSH command directly in the pane with
# no scp, no generated script, no pacing loop. Still writes the done sentinel and
# log, so wait-and-read.sh works unchanged.
#
# CMD is wrapped in single quotes for the remote shell, so keep it a simple
# read-only command without embedded single quotes. For anything fancier, use
# run-remote.sh (which scp's a script and handles quoting).
#
# Even lighter option: for a pure read-only one-shot you don't need to *watch*,
# skip this and the pane entirely — just run `ssh HOST 'cmd'` via a normal Bash
# call and read stdout directly.
set -euo pipefail

HOST="$1"
CMD="$2"

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"
LOG_FILE="$JOB_TMP/shell-pane.log"
DONE_FILE="$JOB_TMP/shell-pane.done"

source "$(dirname "$0")/_pane-lib.sh"

rm -f "$DONE_FILE" "$LOG_FILE"

PANE_ID=$(ensure_shell_pane)

tmux send-keys -t "$PANE_ID" \
  "ssh $HOST '$CMD' 2>&1 | tee $LOG_FILE; touch $DONE_FILE" \
  Enter

echo "Probing $PANE_ID: ssh $HOST '$CMD' (read output with wait-and-read.sh)."
