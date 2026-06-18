#!/usr/bin/env bash
# Integration tests for the shell-pane skill.
#
# Covers the SSH-free surface: _pane-lib.sh (is_shell_pane / ensure_shell_pane),
# run-local.sh, wait-and-read.sh, close-pane.sh. The remote helpers
# (run-remote.sh, probe-remote.sh) share the same pane machinery but need a host,
# so they are exercised indirectly via run-local.sh.
#
# Requires: tmux, pgrep (procps). Operates on a tmux session named `main` on the
# default socket (the session the helpers target). Refuses to run if a `main`
# session already exists, so it never clobbers a real one.
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../_pane-lib.sh
export CLAUDE_JOB_DIR="$(mktemp -d)"
mkdir -p "$CLAUDE_JOB_DIR/tmp"
MARK="$CLAUDE_JOB_DIR/tmp/shell-pane-active"
export SHELL_PANE_PACE=1

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

command -v tmux >/dev/null  || { echo "tmux not installed"; exit 2; }
command -v pgrep >/dev/null || { echo "pgrep (procps) not installed"; exit 2; }

if tmux has-session -t main 2>/dev/null; then
  echo "Refusing to run: a tmux session named 'main' already exists." >&2
  echo "This test owns the 'main' session; close it first." >&2
  exit 2
fi

cleanup() {
  tmux kill-session -t main 2>/dev/null || true
  rm -rf "$CLAUDE_JOB_DIR"
}
trap cleanup EXIT

fresh_main() {
  tmux kill-session -t main 2>/dev/null || true
  tmux new-session -d -s main -x 200 -y 50
  sleep 0.4
}

# Poll for a condition (shell snippet) up to N*0.5s. Returns 0 if it became true.
wait_for() {
  local tries="$1"; shift
  local i
  for (( i = 0; i < tries; i++ )); do
    if eval "$@"; then return 0; fi
    sleep 0.5
  done
  return 1
}

# is_shell_pane lives in the lib; source it for direct assertions.
PANE_FILE="$MARK"
# shellcheck disable=SC1091
source "$SKILL_DIR/_pane-lib.sh"

echo "== Test 1: busy-pane guard opens a fresh pane, leaves the busy one =="
fresh_main
tmux split-window -h -d -t main:0.0
BUSY=$(tmux list-panes -t main:0 -F '#{pane_id}' | tail -1)
echo "$BUSY" > "$MARK"
tmux send-keys -t "$BUSY" 'sleep 300' Enter
wait_for 10 '[ "$(tmux display-message -t "$BUSY" -p "#{pane_current_command}")" = sleep ]' \
  || fail "busy pane never started sleep"
"$SKILL_DIR/run-local.sh" "echo hello" >/dev/null 2>&1
NEW=$(cat "$MARK")
[ "$NEW" != "$BUSY" ] && pass "marker repointed away from busy pane ($BUSY -> $NEW)" \
  || fail "marker still points at busy pane"
{ tmux list-panes -t main:0 -F '#{pane_id}' | grep -q "$BUSY" \
    && [ "$(tmux display-message -t "$BUSY" -p '#{pane_current_command}')" = sleep ]; } \
  && pass "busy pane left running, untouched" || fail "busy pane was disturbed"
"$SKILL_DIR/wait-and-read.sh" 10 2>&1 | grep -q hello \
  && pass "command executed in the fresh pane (saw 'hello')" || fail "command did not run in fresh pane"

echo "== Test 2: is_shell_pane distinguishes idle prompt from a running pipeline =="
fresh_main
IDLE=$(tmux list-panes -t main:0 -F '#{pane_id}' | head -1)
wait_for 10 'is_shell_pane "$IDLE"' && pass "idle prompt classified as shell" \
  || fail "idle prompt not classified as shell"
"$SKILL_DIR/run-local.sh" "sleep 4" >/dev/null 2>&1
RUNPANE=$(cat "$MARK")
sleep 1
if is_shell_pane "$RUNPANE"; then
  fail "running bash|tee pipeline misclassified as idle shell ($(tmux display-message -t "$RUNPANE" -p '#{pane_current_command}'))"
else
  pass "running pipeline classified as busy (name=$(tmux display-message -t "$RUNPANE" -p '#{pane_current_command}'))"
fi
sleep 4

echo "== Test 3: an idle, tracked pane is reused (not replaced) =="
fresh_main
"$SKILL_DIR/run-local.sh" "echo one" >/dev/null 2>&1
"$SKILL_DIR/wait-and-read.sh" 10 >/dev/null 2>&1
sleep 1
A=$(cat "$MARK"); CA=$(tmux list-panes -t main:0 | wc -l)
"$SKILL_DIR/run-local.sh" "echo two" >/dev/null 2>&1
"$SKILL_DIR/wait-and-read.sh" 10 >/dev/null 2>&1
B=$(cat "$MARK"); CB=$(tmux list-panes -t main:0 | wc -l)
{ [ "$A" = "$B" ] && [ "$CA" -eq "$CB" ]; } \
  && pass "idle pane reused (id $A==$B, panes $CA==$CB)" \
  || fail "idle pane not reused (id $A->$B, panes $CA->$CB)"

echo "== Test 4: wait-and-read prints a diagnostic on timeout =="
fresh_main
rm -f "$CLAUDE_JOB_DIR/tmp/shell-pane.done" "$CLAUDE_JOB_DIR/tmp/shell-pane.log"
tmux split-window -h -d -t main:0.0
P=$(tmux list-panes -t main:0 -F '#{pane_id}' | tail -1)
echo "$P" > "$MARK"
tmux send-keys -t "$P" 'sleep 300' Enter
sleep 1
OUT="$("$SKILL_DIR/wait-and-read.sh" 3 2>&1)"
grep -q "TIMEOUT: pane did not finish" <<<"$OUT" && pass "reports TIMEOUT line" || fail "no TIMEOUT line"
grep -q "pane contents at timeout" <<<"$OUT" && pass "captures pane contents on timeout" || fail "no pane capture on timeout"

echo "== Test 5: close-pane leaves a busy pane, closes an idle one =="
fresh_main
tmux split-window -h -d -t main:0.0
B2=$(tmux list-panes -t main:0 -F '#{pane_id}' | tail -1)
echo "$B2" > "$MARK"
tmux send-keys -t "$B2" 'sleep 300' Enter
sleep 1
"$SKILL_DIR/close-pane.sh" >/dev/null 2>&1
sleep 1
tmux list-panes -t main:0 -F '#{pane_id}' | grep -q "$B2" \
  && pass "busy pane left open (process protection preserved)" || fail "close-pane closed a busy pane"

fresh_main
tmux split-window -h -d -t main:0.0
S1=$(tmux list-panes -t main:0 -F '#{pane_id}' | tail -1)
echo "$S1" > "$MARK"
wait_for 10 'is_shell_pane "$S1"' || fail "new pane never reached a shell prompt"
BEFORE=$(tmux list-panes -t main:0 | wc -l)
"$SKILL_DIR/close-pane.sh" >/dev/null 2>&1
# close-countdown counts down 5s then exits the pane.
wait_for 16 '[ "$(tmux list-panes -t main:0 | wc -l)" -lt "$BEFORE" ]' \
  && pass "idle pane countdown-closed" || fail "idle pane not closed"

echo
if [ "$FAILED" = 0 ]; then echo "ALL TESTS PASSED"; else echo "TESTS FAILED"; fi
exit "$FAILED"
