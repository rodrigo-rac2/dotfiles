# New Machine Onboarding Prompt

Paste the following prompt into Claude Code on any new machine to set up shared skills and auto-sync.

---

## Prompt

```
Set up my dotfiles repo on this machine. Here's what needs to happen:

1. Check if `~/dotfiles` already exists. If not, clone it:
   `git clone https://github.com/rodrigo-rac2/dotfiles.git ~/dotfiles`

2. Run `bash ~/dotfiles/setup.sh` — this script will:
   - Detect any skills in `~/.claude/commands/` not yet in the repo, copy them in, commit and push them
   - Replace `~/.claude/commands` with a symlink into the repo
   - Install a SessionStart hook in `~/.claude/settings.json` so every new Claude session pulls the latest skills automatically
   - Install fswatch (macOS) or inotify-tools (Linux) if needed
   - Start a background file watcher (LaunchAgent on macOS, systemd on Linux) that auto-commits and pushes any skill edits within seconds

3. After setup.sh completes, verify:
   - `ls -la ~/.claude/commands` shows a symlink pointing to `~/dotfiles/claude/commands`
   - `ls ~/.claude/commands` lists the skill .md files
   - `cat ~/.claude/settings.json` contains a SessionStart hook pointing to `~/dotfiles/scripts/dotfiles-pull.sh`
   - On macOS: `launchctl list | grep dotfiles` shows the watcher running
   - On Linux: `systemctl --user status dotfiles-watch` shows the watcher active

4. If setup.sh found and committed new skills from this machine, confirm which ones were added.

5. Report back with a summary of what was done and what's now active.
```

---

## What this sets up

| Behavior | How |
|----------|-----|
| Skills shared across machines | `~/.claude/commands` symlinked into `~/dotfiles` (git repo) |
| Pull latest skills on session open | `SessionStart` hook → `dotfiles-pull.sh` |
| Auto-push skill edits | File watcher daemon → commit + push within seconds of any save |
| New machine onboarding | One command: `bash ~/dotfiles/setup.sh` |

## Repo

https://github.com/rodrigo-rac2/dotfiles
