# skills

Claude Code skills for use with [Claude Code](https://claude.ai/code).

## Installation

Clone this repo into your Claude skills directory:

```bash
git clone https://github.com/sageroom/skills ~/.claude/skills-sageroom
```

Or copy individual skill directories into `~/.claude/skills/`.

## Skills

### shell-pane

Runs SSH commands and complex local scripts in a visible tmux pane adjacent to Claude, with paced output (10s between commands) so you can follow along. Pane auto-closes with a countdown at the end of each response.

See [shell-pane/SKILL.md](shell-pane/SKILL.md) for full setup instructions.
