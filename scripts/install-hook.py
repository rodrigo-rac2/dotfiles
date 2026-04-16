#!/usr/bin/env python3
"""
Merges the dotfiles SessionStart hook into ~/.claude/settings.json.
Safe to run multiple times — won't duplicate the hook.
"""
import json
import os
import sys

SETTINGS_PATH = os.path.expanduser("~/.claude/settings.json")
PULL_SCRIPT = os.path.expanduser("~/dotfiles/scripts/dotfiles-pull.sh")

HOOK_COMMAND = f"bash {PULL_SCRIPT}"

def load_settings():
    if os.path.exists(SETTINGS_PATH):
        with open(SETTINGS_PATH) as f:
            return json.load(f)
    return {}

def save_settings(settings):
    with open(SETTINGS_PATH, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")

def hook_already_present(settings):
    hooks = settings.get("hooks", {}).get("SessionStart", [])
    for entry in hooks:
        for h in entry.get("hooks", []):
            if HOOK_COMMAND in h.get("command", ""):
                return True
    return False

def install_hook(settings):
    settings.setdefault("hooks", {}).setdefault("SessionStart", [])
    settings["hooks"]["SessionStart"].append({
        "matcher": "",
        "hooks": [
            {
                "type": "command",
                "command": HOOK_COMMAND,
                "async": True,
                "timeout": 30
            }
        ]
    })
    return settings

def main():
    settings = load_settings()
    if hook_already_present(settings):
        print("SessionStart hook already present — skipping.")
        return
    settings = install_hook(settings)
    save_settings(settings)
    print(f"Installed SessionStart hook → {HOOK_COMMAND}")

if __name__ == "__main__":
    main()
