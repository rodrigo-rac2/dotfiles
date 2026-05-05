---
name: investigate-template-specs
description: Use when the user wants a full audit of template spec state, asks "what needs updating", wants to compare repo vs Azure Portal versions, or needs to know which specs are missing a new version or OS entry. Also triggers on "what's the current state of the template specs" or "which specs need to be updated".
allowed-tools: Bash, Read, Glob, Grep
---

# Investigate Template Spec State

Run in parallel across four areas, then compile a unified report.

## Area 1 — Azure Portal vs repo version matrix
```bash
# What's currently in Azure
az ts list \
  --resource-group eus2-tenant-shared-templates-rg \
  --subscription 8eb6a56e-e1af-430a-9eec-2f4d436eb23c \
  --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in sorted(data, key=lambda x: x['name']):
    print(item['name'])
"
```
Compare against `ls catalog/template-spec/` to find version directories and which specs have the latest version.

## Area 2 — OS library completeness
For each marketplace template spec in the latest version directory:
- Does the `marketplace` variable contain `redhat10`?
- Does the `image` parameter `allowedValues` include `redhat10`?
- Does the `TemplateVersion` `allowedValues` match the version directory name (with `v` prefix)?

```bash
grep -l "redhat10" catalog/template-spec/{latest_version}/*.json
grep -L "redhat10" catalog/template-spec/{latest_version}/*.json
```

## Area 3 — Blob storage sync status
```bash
# ARM templates
echo "=== ARM templates in blob ==="
az storage blob list --account-name eus2bpctenantlibraryst \
  --container-name arm-templates --prefix v{latest_version}/ \
  --query "[].name" -o tsv | wc -l
echo "=== ARM templates in repo ==="
ls catalog/arm-templates/v{latest_version}/ | wc -l

# CSE scripts
echo "=== CSE scripts in blob ==="
az storage blob list --account-name eus2bpctenantlibraryst \
  --container-name custom-script-extensions --prefix v{latest_version}/ \
  --query "[].name" -o tsv | wc -l
echo "=== CSE scripts in repo ==="
find modules/azure/tenant_resources/custom_scripts/v{latest_version}/ -type f | wc -l
```

## Area 4 — Terraform subnet audit
```bash
grep -n "default_outbound_access_enabled" \
  modules/azure/azure_virtual_network/main.tf
```

## Report format
1. **Portal vs repo gap** — specs that exist in Azure but don't have the latest version published
2. **OS library gaps** — marketplace specs missing `redhat10` or other OS entries
3. **Blob gaps** — versions in repo but not fully uploaded to blob storage
4. **Terraform gaps** — subnet properties that need updating
5. **Complete change list** — every file path requiring action

Do NOT make changes — report only.
