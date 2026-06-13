# skills

Claude Code skills for use with [Claude Code](https://claude.ai/code).

Skills are linked into `~/.claude/skills/` via `install.sh`. The repo itself lives separately so it never conflicts with other skills you have installed.

## Installation

Clone to a dedicated directory and run the install script:

```bash
git clone git@github.com:sageroom/skills.git ~/.claude/sageroom-skills
bash ~/.claude/sageroom-skills/install.sh
```

`install.sh` symlinks each skill directory into `~/.claude/skills/`. It is safe to re-run — existing links are replaced cleanly.

## Development

If you want to edit skills, clone to a working directory of your choice instead:

```bash
git clone git@github.com:sageroom/skills.git /your/path/to/skills
bash /your/path/to/skills/install.sh
```

Edits in your working directory take effect immediately — no reinstall needed, since the links point directly to the files.

## Updating

Use the `update-sageroom-skills` Claude Code skill, or run manually:

```bash
# The install script resolves the repo from the symlink — no need to remember where you cloned it
REPO=$(dirname "$(readlink -f ~/.claude/skills/shell-pane)")
git -C "$REPO" pull
bash "$REPO/install.sh"
```

## Skills

### shell-pane

Runs SSH commands and complex local scripts in a visible tmux pane adjacent to Claude, with paced output (10s between commands) so you can follow along. Pane auto-closes with a countdown at the end of each response.

See [shell-pane/SKILL.md](shell-pane/SKILL.md) for full setup instructions including required `~/.claude/settings.json` configuration.
