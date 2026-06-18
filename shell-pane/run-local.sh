#!/usr/bin/env bash
# Usage: run-local.sh CMD1 [CMD2 ...]
# Runs commands locally in a visible tmux pane.
# Output is tee'd to $CLAUDE_JOB_DIR/tmp/shell-pane.log for Claude to read.
# Writes $CLAUDE_JOB_DIR/tmp/shell-pane.done when finished.
#
# Pacing between commands is cosmetic (readability) — the generated script runs
# commands synchronously, so this is not sequencing. Override with SHELL_PANE_PACE.
set -euo pipefail

CMDS=("$@")

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"
LOG_FILE="$JOB_TMP/shell-pane.log"
DONE_FILE="$JOB_TMP/shell-pane.done"
SCRIPT=/tmp/shell-pane-$(date +%s%N).sh
PACE="${SHELL_PANE_PACE:-10}"

source "$(dirname "$0")/_pane-lib.sh"

rm -f "$DONE_FILE" "$LOG_FILE"

# Build the paced script
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'
  first=true
  for cmd in "${CMDS[@]}"; do
    [ "$first" = true ] && first=false || printf 'sleep %s\n' "$PACE"
    printf 'echo ""\necho ">>> %s"\necho ""\n' "$cmd"
    printf '%s\n\n' "$cmd"
  done
  printf 'echo ""\necho "=== done ==="\nrm -- "$0"\n'
} > "$SCRIPT"

# Open or reuse a guarded shell pane (opens fresh if the tracked pane is busy/dead)
PANE_ID=$(ensure_shell_pane)

tmux send-keys -t "$PANE_ID" \
  "bash $SCRIPT 2>&1 | tee $LOG_FILE; touch $DONE_FILE" \
  Enter

# Confirm dispatch: report what was sent, then check the pane picked it up.
# Any of: left-the-shell, done-file written, log non-empty counts as success
# (a fast command may finish before we poll). Informative, not a gate.
echo "Dispatched to $PANE_ID: ${CMDS[*]}"
for _ in 1 2 3 4 5 6; do
  if ! is_shell_pane "$PANE_ID" \
    || [ -f "$DONE_FILE" ] \
    || { [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; }; then
    echo "Confirmed: pane $PANE_ID picked up the command (read output with wait-and-read.sh)."
    exit 0
  fi
  sleep 0.5
done
echo "WARNING: pane $PANE_ID still idle at a shell ~3s after dispatch — the command may not have started." >&2
