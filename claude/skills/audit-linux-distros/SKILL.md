---
name: audit-linux-distros
description: Use when the user asks which Linux distros are supported, wants to add a new Linux distribution, asks "do all specs have redhat10", or needs to know the difference in OS support between gallery and marketplace template specs.
allowed-tools: Bash, Read, Glob, Grep
---

# Audit Linux Distro Coverage

## Key concept: marketplace vs gallery specs
- **Marketplace specs** have a `marketplace` variable mapping OS keys to `publisher`/`offer`/`sku`. These support Linux.
- **Gallery specs** have only a `gallery` variable with internal image references. No `marketplace` block — do NOT add Linux marketplace entries to gallery specs.

## Step 1 — Which specs have a marketplace block?
```bash
grep -l '"marketplace"' catalog/template-spec/{version}/*.json
grep -L '"marketplace"' catalog/template-spec/{version}/*.json
```

## Step 2 — Which OS keys are in each marketplace spec?
```bash
python3 -c "
import json, glob, os
for f in sorted(glob.glob('catalog/template-spec/{version}/*.json')):
    with open(f) as fh:
        try:
            d = json.load(fh)
        except: continue
    mkt = d.get('variables', {}).get('marketplace', {})
    if mkt:
        linux = [k for k,v in mkt.items() if v.get('os') == 'linux']
        print(os.path.basename(f), '->', linux)
"
```

## Step 3 — Check CSE coverage for each Linux type
The ARM templates reference CSE scripts by subdirectory:
- `agent_linux/` — snap agent Linux VMs
- `runner_linux/` — GitHub runner (generic Linux)
- `runner_rhel/` — RHEL-specific runner
- `runner_debian/` — Debian-specific runner

```bash
ls modules/azure/tenant_resources/custom_scripts/v{version}/
```

A new Linux distro needs a CSE subdirectory only if it requires distro-specific setup. RHEL 10 reuses `agent_linux/` (same script as RHEL 8/9).

## Step 4 — Verify blob has CSE for all Linux types
```bash
az storage blob list --account-name eus2bpctenantlibraryst \
  --container-name custom-script-extensions --prefix v{version}/ \
  --query "[].name" -o tsv | grep -v ".DS_Store"
```

## Adding a new Linux distro (e.g. redhat10)
1. Add entry to `marketplace` variable in each applicable marketplace spec JSON:
   ```json
   "redhat10": {
       "publisher": "RedHat",
       "offer": "RHEL",
       "sku": "10-LVM",
       "version": "latest",
       "os": "linux",
       "default": "false"
   }
   ```
2. Add `"redhat10"` to the `image` parameter `allowedValues` array in the same file.
3. If distro needs a new CSE script, add subdirectory under `custom_scripts/v{version}/`. Otherwise it reuses an existing one.
4. Upload updated CSE to blob if new script was added.
