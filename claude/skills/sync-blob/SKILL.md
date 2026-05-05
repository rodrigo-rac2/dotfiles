---
name: sync-blob
description: Use when the user needs to upload ARM templates or Custom Script Extensions (CSEs) to Azure Blob Storage, asks about syncing blob storage for a new version, or encounters InvalidContentLink errors caused by missing files in blob storage. Also triggers on "upload to storage", "blob sync", or "arm templates not in storage".
allowed-tools: Bash, Read, Glob
---

# Sync ARM Templates and CSE Scripts to Blob Storage

## ⚠️ Storage account gotcha
There are two similar accounts. Always use **`eus2bpctenantlibraryst`**.
`eus2bpcavlibraryst` is a different account — its `arm-templates` container will appear empty and is the wrong place.

## Repo constants (platform-microsoft-365)
- Storage account: `eus2bpctenantlibraryst`
- ARM source dir: `catalog/arm-templates/v{version}/`
- CSE source dir: `modules/azure/tenant_resources/custom_scripts/v{version}/`
- ARM blob container: `arm-templates`, path prefix: `v{version}/`
- CSE blob container: `custom-script-extensions`, path prefix: `v{version}/`

## CSE contains 13 subdirectories — upload ALL of them
`agent/`, `agent_linux/`, `build/`, `domain/`, `image/`, `kql/`, `proxy/`,
`runner_debian/`, `runner_linux/`, `runner_rhel/`, `runner_windows/`, `snap/`, `snap_windows/`

Only uploading `agent_linux/` (a common mistake) causes failures for domain controller, runner, and proxy deployments.

## Upload ARM templates
```bash
az storage blob upload-batch \
  --account-name eus2bpctenantlibraryst \
  --destination arm-templates \
  --source catalog/arm-templates/v{version}/ \
  --destination-path v{version} \
  --overwrite \
  --pattern "*.json"
```

## Upload CSE scripts (entire directory)
```bash
az storage blob upload-batch \
  --account-name eus2bpctenantlibraryst \
  --destination custom-script-extensions \
  --source "modules/azure/tenant_resources/custom_scripts/v{version}/" \
  --destination-path v{version} \
  --overwrite
```
Note: if macOS `.DS_Store` files get uploaded, they're harmless but can be cleaned up with `az storage blob delete`.

## Verify what's in blob
```bash
az storage blob list \
  --account-name eus2bpctenantlibraryst \
  --container-name arm-templates \
  --prefix v{version}/ \
  --query "[].name" -o tsv

az storage blob list \
  --account-name eus2bpctenantlibraryst \
  --container-name custom-script-extensions \
  --prefix v{version}/ \
  --query "[].name" -o tsv
```

## Expected counts (v1.6.x)
- ARM templates: 11 `.json` files
- CSE scripts: ~30 files across 13 subdirectories
