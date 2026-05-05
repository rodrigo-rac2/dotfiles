#!/usr/bin/env bash
# setup.sh — bootstrap dotfiles on any machine
# Safe to run multiple times.
set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="$(uname -s)"

echo "=== dotfiles setup (${PLATFORM}) ==="
echo "Repo: $DOTFILES"
echo ""

# ── 1. Claude commands symlink ──────────────────────────────────────────────

CLAUDE_COMMANDS="$HOME/.claude/commands"
mkdir -p "$HOME/.claude"

if [ -L "$CLAUDE_COMMANDS" ]; then
  echo "[commands] Already symlinked: $(readlink "$CLAUDE_COMMANDS")"
else
  if [ -d "$CLAUDE_COMMANDS" ]; then
    echo "[commands] Found existing directory — merging untracked skills..."
    added=0
    for f in "$CLAUDE_COMMANDS"/*.md; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      if [ ! -f "$DOTFILES/claude/commands/$name" ]; then
        cp "$f" "$DOTFILES/claude/commands/$name"
        echo "  Copied: $name"
        added=$((added + 1))
      fi
    done
    if [ "$added" -gt 0 ]; then
      echo "  $added skill(s) copied. Committing..."
      cd "$DOTFILES"
      git add claude/commands/
      git commit -m "merge skills from $(hostname)"
      git push --quiet
    fi
    rm -rf "$CLAUDE_COMMANDS"
  fi
  ln -sf "$DOTFILES/claude/commands" "$CLAUDE_COMMANDS"
  echo "[commands] Symlinked ~/.claude/commands → $DOTFILES/claude/commands"
fi

# ── 2. Claude skills symlink ────────────────────────────────────────────────

CLAUDE_SKILLS="$HOME/.claude/skills"

if [ -L "$CLAUDE_SKILLS" ]; then
  echo "[skills] Already symlinked: $(readlink "$CLAUDE_SKILLS")"
else
  if [ -d "$CLAUDE_SKILLS" ]; then
    echo "[skills] Found existing directory — merging untracked skills..."
    mkdir -p "$DOTFILES/claude/skills"
    added=0
    for d in "$CLAUDE_SKILLS"/*/; do
      [ -d "$d" ] || continue
      name=$(basename "$d")
      if [ ! -d "$DOTFILES/claude/skills/$name" ]; then
        cp -r "$d" "$DOTFILES/claude/skills/$name"
        echo "  Copied: $name"
        added=$((added + 1))
      fi
    done
    if [ "$added" -gt 0 ]; then
      echo "  $added skill(s) copied. Committing..."
      cd "$DOTFILES"
      git add claude/skills/
      git commit -m "merge skills from $(hostname)"
      git push --quiet
    fi
    rm -rf "$CLAUDE_SKILLS"
  fi
  mkdir -p "$DOTFILES/claude/skills"
  ln -sf "$DOTFILES/claude/skills" "$CLAUDE_SKILLS"
  echo "[skills] Symlinked ~/.claude/skills → $DOTFILES/claude/skills"
fi

# ── 3. Claude Code SessionStart hook ────────────────────────────────────────

echo ""
echo "[hook] Installing SessionStart hook into ~/.claude/settings.json..."
python3 "$DOTFILES/scripts/install-hook.py"

# ── 3. File watcher daemon ──────────────────────────────────────────────────

echo ""
if [ "$PLATFORM" = "Darwin" ]; then
  # macOS: install fswatch if missing, then load LaunchAgent
  if ! command -v fswatch &>/dev/null; then
    if command -v brew &>/dev/null; then
      echo "[watcher] Installing fswatch via Homebrew..."
      brew install fswatch --quiet
    else
      echo "[watcher] fswatch not found and Homebrew not available — watcher will use polling fallback."
    fi
  fi

  PLIST_DEST="$HOME/Library/LaunchAgents/com.rac2.dotfiles-watch.plist"
  sed "s|HOME_PLACEHOLDER|$HOME|g" \
    "$DOTFILES/macos/com.rac2.dotfiles-watch.plist.template" \
    > "$PLIST_DEST"

  # Unload existing instance if running, then load fresh
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
  launchctl load -w "$PLIST_DEST"
  echo "[watcher] LaunchAgent loaded: com.rac2.dotfiles-watch"

elif [ "$PLATFORM" = "Linux" ]; then
  # Linux: install inotify-tools if missing, then enable systemd user service
  if ! command -v inotifywait &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      echo "[watcher] Installing inotify-tools..."
      sudo apt-get install -y inotify-tools --quiet
    elif command -v yum &>/dev/null; then
      sudo yum install -y inotify-tools --quiet
    else
      echo "[watcher] inotify-tools not found — watcher will use polling fallback."
    fi
  fi

  SERVICE_DIR="$HOME/.config/systemd/user"
  mkdir -p "$SERVICE_DIR"
  sed "s|HOME_PLACEHOLDER|$HOME|g" \
    "$DOTFILES/linux/dotfiles-watch.service.template" \
    > "$SERVICE_DIR/dotfiles-watch.service"

  systemctl --user daemon-reload
  systemctl --user enable --now dotfiles-watch.service
  echo "[watcher] systemd user service enabled: dotfiles-watch"

else
  echo "[watcher] Unknown platform ($PLATFORM) — skipping daemon install."
  echo "  Run manually: bash $DOTFILES/scripts/dotfiles-watch.sh &"
fi

# ── 4. Make scripts executable ──────────────────────────────────────────────

chmod +x "$DOTFILES/scripts/dotfiles-pull.sh"
chmod +x "$DOTFILES/scripts/dotfiles-watch.sh"
chmod +x "$DOTFILES/scripts/install-hook.py"

# ── 5. Done ─────────────────────────────────────────────────────────────────

echo ""
echo "=== Setup complete ==="
echo ""
echo "Active commands:"
ls "$CLAUDE_COMMANDS"
echo ""
echo "Active skills:"
ls "$CLAUDE_SKILLS"
echo ""
echo "Sync log: ~/.claude/dotfiles-sync.log"
echo ""
echo "To sync manually:"
echo "  Pull: cd ~/dotfiles && git pull"
echo "  Push: cd ~/dotfiles && git add claude/commands/ claude/skills/ && git commit -m 'update' && git push"
