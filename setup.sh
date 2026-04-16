#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles from $DOTFILES_DIR..."

# Claude commands
CLAUDE_COMMANDS="$HOME/.claude/commands"

if [ -L "$CLAUDE_COMMANDS" ]; then
  echo "~/.claude/commands is already a symlink: $(readlink "$CLAUDE_COMMANDS")"
elif [ -d "$CLAUDE_COMMANDS" ]; then
  echo "Found existing ~/.claude/commands directory — checking for untracked skills..."
  added=0
  for f in "$CLAUDE_COMMANDS"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    if [ ! -f "$DOTFILES_DIR/claude/commands/$name" ]; then
      cp "$f" "$DOTFILES_DIR/claude/commands/$name"
      echo "  Copied new skill: $name"
      added=$((added + 1))
    fi
  done
  if [ "$added" -gt 0 ]; then
    echo "  $added new skill(s) copied to repo. Review and commit them:"
    echo "    cd $DOTFILES_DIR && git status && git add claude/commands/ && git commit -m 'merge skills from this machine' && git push"
  fi
  rm -rf "$CLAUDE_COMMANDS"
  ln -sf "$DOTFILES_DIR/claude/commands" "$CLAUDE_COMMANDS"
  echo "~/.claude/commands symlinked to dotfiles."
else
  mkdir -p "$HOME/.claude"
  ln -sf "$DOTFILES_DIR/claude/commands" "$CLAUDE_COMMANDS"
  echo "~/.claude/commands symlinked to dotfiles."
fi

echo ""
echo "Done. Active skills:"
ls "$CLAUDE_COMMANDS"
