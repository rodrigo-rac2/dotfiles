# dotfiles

Personal configuration files for Claude Code, shared across machines and Claude subscriptions.

## What's in here

```
claude/
  commands/       # Global Claude Code skills (~/.claude/commands)
```

## Setup on a new machine

Run these commands once after cloning:

```bash
git clone https://github.com/rodrigo-rac2/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash setup.sh
```

Or manually:

```bash
# Back up existing commands if any exist
[ -d ~/.claude/commands ] && mv ~/.claude/commands ~/.claude/commands.bak

# Symlink claude commands from the repo
mkdir -p ~/.claude
ln -sf ~/dotfiles/claude/commands ~/.claude/commands
```

After that, `~/.claude/commands` points into this repo. Any `git pull` picks up new skills immediately.

## Staying in sync

**Pulling updates (new machine or after changes on another machine):**

```bash
cd ~/dotfiles && git pull
```

The symlink means no copy step — the files are live as soon as the pull completes.

**Adding or editing a skill:**

```bash
# Edit directly in the repo (the symlink means ~/.claude/commands/* IS this folder)
code ~/dotfiles/claude/commands/my-skill.md

# Then commit and push
cd ~/dotfiles
git add claude/commands/
git commit -m "add/update my-skill"
git push
```

**On the other machine, after pushing:**

```bash
cd ~/dotfiles && git pull
```

## Merging skills from another machine

If another machine has skills in `~/.claude/commands/` that are not yet in this repo, do the following **on that machine**:

1. Clone the repo and run setup:
   ```bash
   git clone https://github.com/rodrigo-rac2/dotfiles.git ~/dotfiles
   ```

2. Copy any local skills that don't exist in the repo into the repo:
   ```bash
   for f in ~/.claude/commands/*.md; do
     name=$(basename "$f")
     if [ ! -f ~/dotfiles/claude/commands/"$name" ]; then
       cp "$f" ~/dotfiles/claude/commands/"$name"
       echo "Added: $name"
     fi
   done
   ```

3. Replace the local commands directory with the symlink:
   ```bash
   rm -rf ~/.claude/commands
   ln -sf ~/dotfiles/claude/commands ~/.claude/commands
   ```

4. Review, commit, and push:
   ```bash
   cd ~/dotfiles
   git status
   git add claude/commands/
   git commit -m "merge skills from <machine-name>"
   git push
   ```

5. Pull on the original machine:
   ```bash
   cd ~/dotfiles && git pull
   ```

## Instructions for Claude Code on a new machine

If you (Claude) are reading this after being asked to set up or sync skills on a machine:

1. Check if `~/.claude/commands` is already a symlink into `~/dotfiles`. Run:
   ```bash
   ls -la ~/.claude/commands
   ```

2. **If it is a symlink** — just run `cd ~/dotfiles && git pull`. Done.

3. **If it is a regular directory** (not yet symlinked):
   - Copy any `.md` files in `~/.claude/commands/` that are NOT already in `~/dotfiles/claude/commands/` into the repo.
   - Commit them (with message "merge skills from this machine").
   - Push.
   - Delete `~/.claude/commands` and symlink it: `ln -sf ~/dotfiles/claude/commands ~/.claude/commands`.
   - Confirm the symlink is working by listing `~/.claude/commands`.

4. **If `~/dotfiles` does not exist** — clone it first:
   ```bash
   git clone https://github.com/rodrigo-rac2/dotfiles.git ~/dotfiles
   ```
   Then follow step 3.

5. After setup, always verify with:
   ```bash
   ls -la ~/.claude/commands   # should show -> /Users/<user>/dotfiles/claude/commands
   ls ~/.claude/commands        # should list all the .md skill files
   ```

## Skills currently in this repo

| Skill | Description |
|-------|-------------|
| `add-xray-tests` | Add Xray Tests — Create Manual Test Tickets from a Test Plan |
| `code-review` | Code Review — Deep Human-Like PR Review |
| `create-bug-blackpoint` | Create Bug — Blackpoint (C1 Project) |
| `create-manual-testing-ticket` | Create Manual Testing Ticket |
| `jira-sync` | Jira Sync — Sync Daily Log from Jira Activity |
| `log-daily` | Log Daily — Update Daily Work Log |
| `qa-stamp` | QA Stamp — Post Test Results to Jira |
| `retro` | Retro — Generate Sprint Retrospective |
| `standup` | Standup — Generate Daily Scrum Update |
| `standup-endofday` | Standup End of Day — Generate Daily Status Report |
| `standup-startofday` | Standup Start of Day — Generate Morning Scrum Update |
| `weekly-plan` | Weekly Plan — Generate Weekly Status & Plan Report |
| `weekly-report` | Weekly Report — Generate Weekly Status Report |
