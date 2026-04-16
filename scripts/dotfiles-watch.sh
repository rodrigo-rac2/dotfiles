#!/usr/bin/env bash
# Watches ~/dotfiles/claude/commands/ for changes and auto-commits/pushes.
# Run as a background daemon via LaunchAgent (macOS) or systemd (Linux).

DOTFILES="$HOME/dotfiles"
WATCH_DIR="$DOTFILES/claude/commands"
LOG="$HOME/.claude/dotfiles-sync.log"

commit_and_push() {
  cd "$DOTFILES" || return
  # Only act if there are staged or unstaged changes in claude/commands/
  if git status --porcelain claude/commands/ | grep -q .; then
    git add claude/commands/
    CHANGED=$(git diff --cached --name-only | xargs -I{} basename {} .md | tr '\n' ', ' | sed 's/, $//')
    git commit -m "auto-sync: $CHANGED" --quiet
    git push --quiet origin main
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] pushed: $CHANGED" >>"$LOG"
  fi
}

# Pull once on daemon start to ensure we're up to date
cd "$DOTFILES" && git pull --quiet --rebase origin main >>"$LOG" 2>&1

# Use fswatch if available (macOS), inotifywait on Linux, fall back to polling
if command -v fswatch &>/dev/null; then
  fswatch -o --event Created --event Updated --event Removed --event Renamed "$WATCH_DIR" \
    | while read -r _; do
        sleep 3  # debounce — wait for editor to finish writing
        commit_and_push
      done
elif command -v inotifywait &>/dev/null; then
  inotifywait -m -r -e modify,create,delete,moved_to "$WATCH_DIR" --format '%f' \
    | while read -r _; do
        sleep 3
        commit_and_push
      done
else
  # Polling fallback — checks every 15 seconds
  while true; do
    sleep 15
    commit_and_push
  done
fi
