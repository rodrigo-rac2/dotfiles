#!/usr/bin/env bash
# Run by Claude Code SessionStart hook.
# Pulls latest dotfiles (skills) from remote so every session starts fresh.

DOTFILES="$HOME/dotfiles"
LOG="$HOME/.claude/dotfiles-sync.log"

cd "$DOTFILES" || exit 0

echo "Syncing skills..." > /dev/tty

# Stash any local uncommitted changes before pulling (shouldn't normally happen)
git fetch --quiet origin main 2>>"$LOG"

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "Skills up to date."
  echo "Skills up to date." > /dev/tty
  exit 0
fi

git pull --quiet --rebase origin main >>"$LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] pull: $(git log --oneline -1)" >>"$LOG"
MSG="Skills synced: $(git log --oneline -1)"
echo "$MSG"
echo "$MSG" > /dev/tty
