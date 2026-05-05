---
name: release-version
description: Use when the user wants to release a new template spec version end-to-end, asks "how do I cut a new version", wants to bump from one version to the next, or says "release v1.6.2" or similar. This is the full three-way sync workflow from repo files through to Azure Portal and blob storage.
allowed-tools: Bash, Read, Glob, Grep, Edit, Write
---

# Full Version Release — Three-Way Sync

Releasing a new version requires all three stores to be updated or deployments fail with `InvalidContentLink`.

## Pre-flight checklist
- [ ] New version JSON exists in `catalog/template-spec/{new_version}/`
- [ ] New version ARM templates exist in `catalog/arm-templates/v{new_version}/`
- [ ] New version CSE scripts exist in `modules/azure/tenant_resources/custom_scripts/v{new_version}/`
- [ ] All template spec JSON files have `TemplateVersion` `allowedValues` updated to `["v{new_version}"]`
- [ ] New OS entries (e.g. `redhat10`) added to `marketplace` variable in applicable marketplace specs

## Step 1 — Create repo files (if not already done)
```bash
# Copy from previous version
cp -r catalog/template-spec/{base_version}/ catalog/template-spec/{new_version}/
cp -r catalog/arm-templates/v{base_version}/ catalog/arm-templates/v{new_version}/
cp -r modules/azure/tenant_resources/custom_scripts/v{base_version}/ \
       modules/azure/tenant_resources/custom_scripts/v{new_version}/
```
Then update `TemplateVersion` allowedValues in every spec JSON:
```bash
find catalog/template-spec/{new_version}/ -name "*.json" -exec \
  sed -i '' 's/"v{base_version}"/"v{new_version}"/g' {} \;
```

## Step 2 — Publish template specs to Azure Portal
For each of the 9 deployed specs:
```bash
az ts create \
  --name {spec_name} --version {new_version} \
  --resource-group eus2-tenant-shared-templates-rg \
  --subscription 8eb6a56e-e1af-430a-9eec-2f4d436eb23c \
  --template-file catalog/template-spec/{new_version}/{spec_name}.json \
  --yes
```
Grant/revoke `Template Spec Contributor` RBAC on `eus2-tenant-shared-templates-rg` if needed.

## Step 3 — Upload ARM templates to blob
```bash
az storage blob upload-batch \
  --account-name eus2bpctenantlibraryst \
  --destination arm-templates \
  --source catalog/arm-templates/v{new_version}/ \
  --destination-path v{new_version} \
  --overwrite --pattern "*.json"
```

## Step 4 — Upload CSE scripts to blob (all 13 subdirs)
```bash
az storage blob upload-batch \
  --account-name eus2bpctenantlibraryst \
  --destination custom-script-extensions \
  --source "modules/azure/tenant_resources/custom_scripts/v{new_version}/" \
  --destination-path v{new_version} \
  --overwrite
```

## Step 5 — Verify end-to-end
```bash
# Spot-check: ARM templates in blob
az storage blob list --account-name eus2bpctenantlibraryst \
  --container-name arm-templates --prefix v{new_version}/ --query "[].name" -o tsv | wc -l
# Expected: 11

# Spot-check: CSE in blob
az storage blob list --account-name eus2bpctenantlibraryst \
  --container-name custom-script-extensions --prefix v{new_version}/ --query "[].name" -o tsv | wc -l
# Expected: ~31 (30 scripts + .DS_Store if on macOS)
```
Then deploy a test VM from the new template spec version to confirm end-to-end.

## Known CI/CD gap
The pipeline does NOT automatically upload ARM templates or CSE scripts to blob on merge. Steps 3 and 4 must always be done manually until that's fixed.
