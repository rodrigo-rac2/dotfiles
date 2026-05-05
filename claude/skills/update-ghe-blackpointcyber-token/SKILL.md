---
name: update-ghe-blackpointcyber-token
description: Use when the user needs to update or rotate the BlackpointCyber GHE (GitHub Enterprise) NPM token, says the token expired, gets 401 errors from npm install, or asks to "update the bp cyber token" or "update the blackpoint token". Refreshes GHE_NPM_READ_TOKEN in ~/.zshrc.
allowed-tools: AskUserQuestion, Read, Edit, Bash
---

# Update GHE NPM Token

The GHE NPM token (`GHE_NPM_READ_TOKEN`) is stored in `~/.zshrc` and referenced by `~/.npmrc` via `${GHE_NPM_READ_TOKEN}`.

## Steps

1. **Open the token creation page in the browser** using Bash:
   ```bash
   open "https://github.bpcyber.com/settings/tokens/new?scopes=read%3Apackages&description=GHE_NPM_READ_TOKEN"
   ```
   Tell the user: "The token creation page should open in your browser with `read:packages` pre-selected. Set an expiration, click Generate token, and paste it here."

2. **Ask the user to paste the new token.**

3. **Read `~/.zshrc`** to find the current token line.

4. **Edit `~/.zshrc`** — replace the existing `export GHE_NPM_READ_TOKEN=...` line with the new token value.

5. **Tell the user to run** `source ~/.zshrc` in their terminal (Claude cannot persist env vars into the user's shell session).

6. Optionally verify with `npm config list` that `//npm.github.bpcyber.com/:_authToken` shows `${GHE_NPM_READ_TOKEN}` (not a hardcoded value).

## Notes
- `~/.npmrc` uses `${GHE_NPM_READ_TOKEN}` — do NOT hardcode the token there.
- Token must have `read:packages` scope.
- If `npm ci` still fails after sourcing, confirm the shell picked up the new value with `echo $GHE_NPM_READ_TOKEN`.
- Confluence reference: https://bpcyber.atlassian.net/wiki/spaces/sre/pages/2630254596/GHE+NPM+Setup+Local+Development
