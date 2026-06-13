---
name: update-sageroom-skills
description: Pull the latest sageroom/skills from GitHub and re-link all skills into ~/.claude/skills/. Use when the user asks to update their sageroom skills.
---

# Update Sageroom Skills

Pull the latest changes from the sageroom/skills repo and re-link all skills.

## How it works

The repo location is resolved from the symlink on any installed skill — works whether the user did a standard install (`~/.claude/sageroom-skills/`) or a dev install (anywhere else).

```bash
# Resolve repo path from the symlink
REPO=$(dirname "$(readlink -f ~/.claude/skills/shell-pane)")

# Pull latest
git -C "$REPO" pull

# Re-link all skills (idempotent, adds any new skills automatically)
bash "$REPO/install.sh"
```

After updating, report which skills are now installed and mention any new ones that were added.
