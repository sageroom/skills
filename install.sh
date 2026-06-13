#!/usr/bin/env bash
# Links all skills from this repo into ~/.claude/skills/.
# Works whether the repo is cloned for development or installed directly.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${HOME}/.claude/skills"
mkdir -p "$SKILLS_DIR"

linked=0
for skill in "$REPO"/*/; do
  [ -f "${skill}SKILL.md" ] || continue
  name="$(basename "$skill")"
  target="$SKILLS_DIR/$name"
  # Remove existing link or directory if it points elsewhere
  if [ -L "$target" ] || [ -d "$target" ]; then
    rm -rf "$target"
  fi
  ln -s "$skill" "$target"
  echo "  linked: $name"
  linked=$((linked + 1))
done

echo "Done — $linked skill(s) linked from $REPO"
