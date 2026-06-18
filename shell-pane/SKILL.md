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

Also confirm tmux is installed and Claude Code is running inside a tmux session:

```bash
~/.claude/skills/shell-pane/check-setup.sh
```

If it errors, ask the user to restart Claude Code inside tmux: `tmux new-session -s main` then relaunch.

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
- Pace output with a cosmetic `sleep` between commands so the user can read it
  (default 10s, override with `SHELL_PANE_PACE`). This is readability only — the
  generated script runs commands synchronously, so it is not sequencing.
- Tee all output to `$CLAUDE_JOB_DIR/tmp/shell-pane.log`
- Write `$CLAUDE_JOB_DIR/tmp/shell-pane.done` when finished
- Clean up the temp script on exit

### Pane guard and self-heal

Before dispatching, the helpers check that the tracked pane is **alive and at a
shell prompt**. If the tracked pane is dead, missing, or **busy running a
foreground process** (e.g. a server you left running), they open a *fresh* pane
and repoint the marker instead of typing keystrokes into that process. The busy
pane is left running, never killed. This is the same shell-only guard
`close-pane.sh` uses to protect a running process from the Stop hook — the send
path is now as defensive as the close path.

`run-remote.sh` / `run-local.sh` also print a one-line dispatch confirmation
(`Dispatched to %N: …` then `Confirmed: …`) so the otherwise-silent send is
visible. The confirmation is informative, not proof of success — you still must
read the actual output (see below).

## Verify every launch

**The Bash call to `run-remote.sh` / `run-local.sh` returns immediately after firing `tmux send-keys`.** It prints only a short dispatch confirmation — that is NOT the command's output and NOT proof it succeeded. You must verify that the command actually ran before telling the user anything. (A `WARNING:` line means the pane was still idle ~3s after dispatch — investigate before reporting success.)

The method depends on whether the command terminates:

### Terminating commands (scripts, one-shots, pipelines)

Call `wait-and-read.sh` — it blocks until `shell-pane.done` is written, then prints the log:

```bash
~/.claude/skills/shell-pane/wait-and-read.sh          # default 120s timeout
~/.claude/skills/shell-pane/wait-and-read.sh 300       # custom timeout
```

If the output shows an error (command not found, permission denied, etc.), handle it — don't silently move on.

On timeout, `wait-and-read.sh` now captures and prints the pane contents under a
`--- pane contents at timeout ---` header instead of a bare `TIMEOUT:` line. If
that capture shows a shell prompt or an unrelated running process, the command
never executed — read it as the diagnostic it is, don't just retry blindly.

### Interactive / non-terminating commands (btop, vim, less, watch…)

`wait-and-read.sh` will hang until timeout because `shell-pane.done` is never written. Instead, use:

```bash
~/.claude/skills/shell-pane/verify-interactive.sh        # default 3s wait
~/.claude/skills/shell-pane/verify-interactive.sh 5      # custom wait
```

This sleeps briefly then captures the pane. Read the output: if it shows the expected TUI, report success. If it shows an error ("command not found", SSH failure), handle it.

The user cannot see your tool calls, only your text — "it's running" without verified output is a false claim.

### Install-then-interactive (e.g. apt install followed by a TUI)

When a command sequence installs a tool and then launches an interactive TUI, **split into two separate `run-remote.sh` calls**. Do not bundle them in one call and guess a sleep duration — the install time is unpredictable and a long sleep is visible to the user as a freeze.

```bash
# Step 1: install (terminating — wait for it properly)
~/.claude/skills/shell-pane/run-remote.sh HOST "sudo apt install -y <tool>"
~/.claude/skills/shell-pane/wait-and-read.sh 300

# Step 2: launch the TUI (interactive — verify with a brief capture)
~/.claude/skills/shell-pane/run-remote.sh HOST "<tool>"
~/.claude/skills/shell-pane/verify-interactive.sh 3
```

### Commands needing sudo

`run-remote.sh` uses `ssh -t`, which allocates a TTY, so a `sudo` password prompt
appears **in the visible pane** and the user types it there. The bundled script
runs synchronously, so `sudo` blocks until the password is entered — there is no
internal pacing problem to solve here.

The one real failure is a *second* dispatch fired while a prior `sudo` is still
waiting on its password: those keystrokes would land in the running session. The
pane guard prevents this (it sees the busy pane and opens a fresh one), but that
fresh pane isn't where your sudo command is. So:

- Put a `sudo` command in its **own** `run-remote.sh` call.
- Use a generous `wait-and-read.sh` timeout (the user may take a while to type).
- **Never fire the next dispatch until `wait-and-read.sh` returns.**

> Note: the idea of "prompt-aware pacing" between commands belongs to an older
> send-keys-per-command model. The current helpers bundle commands into one
> synchronous script, so the only collision is the cross-call one above.

### Read-only one-shot probes

For a quick read-only probe you don't need to *watch*, skip the pane ceremony
entirely — just run `ssh HOST 'cmd'` via a normal Bash call and read stdout. No
scp, no sentinel, no pane.

If you do want it visible, `probe-remote.sh` runs a single SSH command directly
in the guarded pane (no scp, no generated script):

```bash
~/.claude/skills/shell-pane/probe-remote.sh HOST "df -h"
~/.claude/skills/shell-pane/wait-and-read.sh
```

## Installing missing tools

If a command fails because a tool isn't installed and you decide to install it, you must tell the user **before running the install**:

- A one-liner explaining what the tool is
- A link to its documentation or homepage

Example:
> Installing **btop** — a resource monitor showing CPU, memory, disk, and network with live graphs. [github.com/aristocratos/btop](https://github.com/aristocratos/btop)

Never silently `apt install` something without this disclosure. The user may not want it, or may want to review it first.

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
