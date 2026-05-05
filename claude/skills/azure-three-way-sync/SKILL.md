---
name: azure-three-way-sync
description: Use when the user encounters InvalidContentLink errors from Azure deployments, needs to release a new template spec version end-to-end, asks about uploading ARM templates or CSE scripts to blob storage, or needs to verify that a new version is fully deployed across all three required locations.
allowed-tools: Bash, Read, Glob, Grep
---

# Azure Three-Way Sync Pattern

## What it is
ARM-based deployments that use nested templates (Template Specs calling ARM templates from blob storage) require three separate stores to be in sync. Missing any one of them causes `InvalidContentLink` errors at deployment time — even if the Portal UI shows the template spec successfully published.

## The three stores

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Portal                         │
│  Template Spec (az ts create)                          │
│  catalog/template-spec/{version}/*.json                │
└────────────────────┬────────────────────────────────────┘
                     │ calls nested templates via URL
┌────────────────────▼────────────────────────────────────┐
│             Blob Storage: arm-templates                 │
│  {storage_account}/arm-templates/v{version}/*.json     │
│  catalog/arm-templates/v{version}/*.json               │
└────────────────────┬────────────────────────────────────┘
                     │ VM extension points to CSE scripts
┌────────────────────▼────────────────────────────────────┐
│      Blob Storage: custom-script-extensions             │
│  {storage_account}/custom-script-extensions/v{ver}/    │
│  modules/azure/tenant_resources/custom_scripts/v{ver}/ │
└─────────────────────────────────────────────────────────┘
```

## Release checklist for a new version

- [ ] Template spec JSON files copied/updated in `catalog/template-spec/{new_version}/`
- [ ] ARM template JSON files copied/updated in `catalog/arm-templates/v{new_version}/`
- [ ] CSE scripts copied/updated in `modules/azure/tenant_resources/custom_scripts/v{new_version}/`
- [ ] All template spec JSON: `TemplateVersion` `allowedValues` updated to `["v{new_version}"]`
- [ ] PR merged (or at minimum files exist in repo)
- [ ] Template specs published: `az ts create` for each spec at new version
- [ ] ARM templates uploaded: `az storage blob upload-batch` to `arm-templates/v{new_version}/`
- [ ] CSE scripts uploaded: `az storage blob upload-batch` to `custom-script-extensions/v{new_version}/`
- [ ] Test deployment end-to-end from Portal

## Diagnosing InvalidContentLink

When a deployment fails with `InvalidContentLink`, check in this order:
1. Is the template spec published at the expected version? → `az ts show`
2. Are ARM templates in blob? → `az storage blob list --container-name arm-templates --prefix v{version}/`
3. Are CSE scripts in blob? → `az storage blob list --container-name custom-script-extensions --prefix v{version}/`
4. Does the `template_version` variable in the ARM template match what's in blob? (look for `v` prefix — it's `v1.6.1` not `1.6.1`)

## Common gotchas

**Wrong storage account**: There are two similar accounts — `eus2bpctenantlibraryst` (correct) and `eus2bpcavlibraryst` (wrong). The AV account's `arm-templates` container appears empty. Always confirm you're in `eus2bpctenantlibraryst` before troubleshooting.

**Partial CSE upload**: A common mistake is only uploading `agent_linux/bpc_agent_cse.sh`. The full CSE tree has 13 subdirectories and ~30 files (`agent/`, `agent_linux/`, `build/`, `domain/`, `image/`, `kql/`, `proxy/`, `runner_debian/`, `runner_linux/`, `runner_rhel/`, `runner_windows/`, `snap/`, `snap_windows/`). Upload the entire directory with `az storage blob upload-batch`.

**Windows works, Linux fails**: The Windows CSE often gets uploaded first/separately. Always verify `agent_linux/` is present — it's a separate path from `agent/` (Windows).

**Previous version worked, new version doesn't**: This almost always means blob storage wasn't synced. The template spec constructs the nested template URL dynamically from the `TemplateVersion` parameter, so v1.6.0 blobs won't satisfy a v1.6.1 deployment.

## Known gap in CI/CD
The platform-microsoft-365 pipeline does NOT automatically upload ARM templates or CSE scripts to blob storage on merge. This must be done manually after each version release. This is documented in the repo README. Future work: fix the GitHub Actions workflow to automate blob uploads on merge to master.
