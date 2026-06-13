---
name: shell-pane
description: Run SSH commands or complex multi-step local scripts in a visible tmux pane adjacent to Claude. Use for any SSH command, any multi-command script, or any unusual local command. Skip for simple one-liners (git status, find, grep, ls, etc.).
---

# Shell Pane

Open a visible tmux pane for any command the user should be able to watch. Each agent session gets its own isolated pane.

## First-time setup

The helper scripts need to be in the Bash allowlist so they run without a permission prompt. Check that `~/.claude/settings.json` contains this rule — if not, add it before proceeding:

```json
"permissions": {
  "allow": [
    "Bash(~/.claude/skills/shell-pane/*.sh*)"
  ]
}
```

Also confirm tmux is installed (`which tmux`) and Claude Code is running inside a tmux session (`tmux display-message -p '#S'`). If not in tmux, ask the user to restart Claude Code inside one: `tmux new-session -s main` then relaunch.

The `Stop` hook is also required — it fires at the end of every response and closes the pane (with a 5s countdown so the user can interrupt). Without it, panes stay open permanently. Add this to `~/.claude/settings.json`:

```json
"hooks": {
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/skills/shell-pane/close-pane.sh",
          "async": true
        }
      ]
    }
  ]
}
```

## When to use

**Always use this skill for:**
- Any SSH command on a remote host
- Any multi-command script or pipeline
- Any unusual or non-trivial local command the user might want to inspect

**Skip for simple one-liners:** `git status`, `find`, `grep`, `ls`, `cat`, and similar read-only or fast commands that produce small output.

## Running commands

All boilerplate lives in pre-written helpers. Bash calls contain only the meaningful content — host and commands.

**Remote (SSH):**
```bash
~/.claude/skills/shell-pane/run-remote.sh HOST "command one" "command two"
```

**Local:**
```bash
~/.claude/skills/shell-pane/run-local.sh "command one" "command two"
```

Each command is a quoted string. The helpers:
- Print each command before running it (`>>> command`)
- Sleep 10s between commands so the user can read output
- Tee all output to `$CLAUDE_JOB_DIR/tmp/shell-pane.log`
- Write `$CLAUDE_JOB_DIR/tmp/shell-pane.done` when finished
- Clean up the temp script on exit

## Reading the output

After launching, use `wait-and-read.sh` to block until the script finishes and print the captured output:

```bash
~/.claude/skills/shell-pane/wait-and-read.sh          # default 120s timeout
~/.claude/skills/shell-pane/wait-and-read.sh 300       # custom timeout
```

This lets Claude see the command results without asking the user.

## Closing the pane

```bash
~/.claude/skills/shell-pane/close-pane.sh
```

Call this when work is complete. The next task will get a fresh pane.

## Pane isolation

Pane tracking is scoped to `$CLAUDE_JOB_DIR/tmp/shell-pane-active`, which is unique per agent session. Different agents open and manage their own panes independently — no cross-session sharing.

## Pane lifecycle

The helpers automatically reuse an existing pane if one is alive for this session, or open a fresh one if not. For continuous work, call the helpers repeatedly — they reuse the same pane. Call `close-pane.sh` when the task is done.

## Pane layout for parallel work

When you need multiple panes running in parallel, open them manually before sending any commands, stacking right-then-down:

```
┌─────────────────┬────────────────┐
│                 │   pane 1       │
│   Claude        ├────────────────┤
│   main:0.0      │   pane 2       │
│                 ├────────────────┤
│                 │   pane 3       │
└─────────────────┴────────────────┘
```

```bash
tmux split-window -h -d -t main:0.0   # pane 1
tmux split-window -v -d -t main:0.1   # pane 2
tmux split-window -v -d -t main:0.2   # pane 3
```

Then use `tmux send-keys -t <pane_id> "..."` to target each pane directly.
