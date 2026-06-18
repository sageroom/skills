#!/usr/bin/env bash
# Usage: run-remote.sh HOST CMD1 [CMD2 ...]
# Runs commands on a remote host in a visible tmux pane.
# Output is tee'd to $CLAUDE_JOB_DIR/tmp/shell-pane.log for Claude to read.
# Writes $CLAUDE_JOB_DIR/tmp/shell-pane.done when finished.
#
# Pacing between commands is cosmetic (readability) — the generated script runs
# commands synchronously, so this is not sequencing. Override with SHELL_PANE_PACE.
set -euo pipefail

HOST="$1"
shift
CMDS=("$@")

JOB_TMP="${CLAUDE_JOB_DIR}/tmp"
PANE_FILE="$JOB_TMP/shell-pane-active"
LOG_FILE="$JOB_TMP/shell-pane.log"
DONE_FILE="$JOB_TMP/shell-pane.done"
REMOTE_SCRIPT=/tmp/shell-pane-$(date +%s%N).sh
PACE="${SHELL_PANE_PACE:-10}"

source "$(dirname "$0")/_pane-lib.sh"

rm -f "$DONE_FILE" "$LOG_FILE"

# Build the paced script (runs on remote, tees output back via SSH stdout)
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'
  first=true
  for cmd in "${CMDS[@]}"; do
    [ "$first" = true ] && first=false || printf 'sleep %s\n' "$PACE"
    printf 'echo ""\necho ">>> %s"\necho ""\n' "$cmd"
    printf '%s\n\n' "$cmd"
  done
  printf 'echo ""\necho "=== done ==="\nrm -- "$0"\n'
} > /tmp/shell-pane-local-$$.sh

scp -q /tmp/shell-pane-local-$$.sh "$HOST":"$REMOTE_SCRIPT"
rm /tmp/shell-pane-local-$$.sh

# Open or reuse a guarded shell pane (opens fresh if the tracked pane is busy/dead)
PANE_ID=$(ensure_shell_pane)

# Run on remote; tee output to log; write sentinel when done
tmux send-keys -t "$PANE_ID" \
  "ssh -t $HOST 'bash $REMOTE_SCRIPT' 2>&1 | tee $LOG_FILE; rm -f $REMOTE_SCRIPT; touch $DONE_FILE" \
  Enter

# Confirm dispatch: report what was sent, then check the pane actually picked it
# up. A fast command may finish (done-file / non-empty log) before we poll, so
# any of: left-the-shell, done-file written, log non-empty counts as success.
# Informative, not a gate — the shell guard above already prevents keystrokes
# landing in a wrong process.
echo "Dispatched to $PANE_ID: ssh $HOST '${CMDS[*]}'"
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
