#!/usr/bin/env bash
# Verify tmux is installed and Claude Code is running inside a tmux session.
# Prints the session name on success; exits 1 with a message on failure.
set -euo pipefail

if ! command -v tmux &>/dev/null; then
  echo "ERROR: tmux is not installed. Install it with: sudo apt install tmux" >&2
  exit 1
fi

SESSION=$(tmux display-message -p '#S' 2>/dev/null || true)
if [ -z "$SESSION" ]; then
  echo "ERROR: not inside a tmux session. Restart Claude Code inside one: tmux new-session -s main" >&2
  exit 1
fi

echo "tmux session: $SESSION"
