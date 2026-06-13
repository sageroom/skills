#!/usr/bin/env bash
# Usage: run-local.sh CMD1 [CMD2 ...]
# Runs commands locally in a visible tmux pane, 10s between each.
# Output is tee'd to $CLAUDE_JOB_DIR/tmp/shell-pane.log for Claude to read.
# Writes $CLAUDE_JOB_DIR/tmp/shell-pane.done when finished.
set -euo pipefail

CMDS=("$@")

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"
LOG_FILE="$JOB_TMP/shell-pane.log"
DONE_FILE="$JOB_TMP/shell-pane.done"
SCRIPT=/tmp/shell-pane-$(date +%s%N).sh

rm -f "$DONE_FILE" "$LOG_FILE"

# Build the paced script
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'
  first=true
  for cmd in "${CMDS[@]}"; do
    [ "$first" = true ] && first=false || printf 'sleep 10\n'
    printf 'echo ""\necho ">>> %s"\necho ""\n' "$cmd"
    printf '%s\n\n' "$cmd"
  done
  printf 'echo ""\necho "=== done ==="\nrm -- "$0"\n'
} > "$SCRIPT"

# Open or reuse pane
PANE_ID=$(cat "$PANE_FILE" 2>/dev/null || true)
if [ -z "$PANE_ID" ] || ! tmux list-panes -t "$PANE_ID" &>/dev/null 2>&1; then
  tmux split-window -h -d -t main:0.0
  PANE_ID=$(tmux list-panes -t main:0 -F '#{pane_id}' | tail -1)
  echo "$PANE_ID" > "$PANE_FILE"
fi

tmux send-keys -t "$PANE_ID" \
  "bash $SCRIPT 2>&1 | tee $LOG_FILE; touch $DONE_FILE" \
  Enter
