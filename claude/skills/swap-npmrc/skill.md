# Swap npmrc

Swaps `~/.npmrc` between the default config and the BPCyber-scoped config.

## When to Use

- Starting work on a BPCyber project that needs `@engineering` scoped packages from `npm.github.bpcyber.com`
- Switching back to a non-BPCyber project (proparcs, personal, etc.)
- Triggered by: "swap npmrc", "use bpcyber npmrc", "switch to default npmrc", "activate bp registry"

## Files

| File | Purpose |
|------|---------|
| `~/.npmrc` | Active npmrc used by npm |
| `~/.bp-npmrc` | BPCyber registry config (`@engineering` → `npm.github.bpcyber.com`) |
| `~/.default-npmrc` | Default config (no BPCyber scopes) |

## Workflow

### Phase 1: Detect current state

Check which config is active by inspecting `~/.npmrc` for the presence of `bpcyber`.

### Phase 2: Swap

**To activate BPCyber:**
```bash
cp ~/.npmrc ~/.default-npmrc   # back up current
cp ~/.bp-npmrc ~/.npmrc        # activate bp config
```

**To restore default:**
```bash
cp ~/.npmrc ~/.bp-npmrc        # back up current (keeps bp-npmrc up to date)
cp ~/.default-npmrc ~/.npmrc   # restore default
```

### Phase 3: Confirm

Print which config is now active and what registries are configured.

## Notes

- `GHE_NPM_READ_TOKEN` must be set in `~/.zshrc` for BPCyber registry to authenticate
- The swap is reversible — always back up before overwriting
- Do NOT commit `~/.npmrc` to any repo
