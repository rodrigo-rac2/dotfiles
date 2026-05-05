---
name: azure-template-specs
description: Use when working with Azure Template Specs — publishing new versions, investigating what needs updating, auditing version coverage across the Azure Portal vs a git repo, or troubleshooting InvalidContentLink deployment errors. Also applies when the user mentions "template spec", "az ts create", "TS version", or publishing ARM templates to Azure Portal.
allowed-tools: Bash, Read, Glob, Grep, Edit, Write
---

# Azure Template Spec Workflows

## Core concepts

**Template Specs** are versioned ARM templates stored in Azure and referenced by portal deployments. They live in an Azure resource group and are published with `az ts create`.

**Three-way sync** — deployments fail with `InvalidContentLink` if any of these three are out of sync:
1. **Template Spec** in Azure Portal → `az ts create --name {spec} --version {ver} --resource-group {rg} --template-file {file}`
2. **ARM templates** in blob storage → `az storage blob upload-batch --destination arm-templates --source {dir} --destination-path v{ver}`
3. **CSE scripts** in blob storage → `az storage blob upload-batch --destination custom-script-extensions --source {dir} --destination-path v{ver}`

## CLI workflows

### Check what's deployed in Azure
```bash
az ts list --resource-group {rg} --subscription {sub} --output table
```

### Publish a template spec version
```bash
az ts create \
  --name {spec_name} \
  --version {version} \
  --resource-group {rg} \
  --subscription {sub} \
  --template-file {path/to/spec.json} \
  --yes
```

### Check versions of a specific spec
```bash
az ts show --name {spec_name} --resource-group {rg} --subscription {sub} \
  --output json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['name'], d.get('versions', []))"
```

### Upload ARM templates to blob
```bash
az storage blob upload-batch \
  --account-name {storage_account} \
  --destination arm-templates \
  --source {local_dir} \
  --destination-path v{version} \
  --overwrite
```

### Verify blob contents
```bash
az storage blob list \
  --account-name {storage_account} \
  --container-name arm-templates \
  --prefix v{version}/ \
  --query "[].name" -o table
```

## RBAC for publishing
Personal user accounts often lack `Microsoft.Resources/templateSpecs/write`. Grant temporarily:
```bash
az role assignment create \
  --assignee "{user_email}" \
  --role "Template Spec Contributor" \
  --scope "/subscriptions/{sub}/resourceGroups/{rg}"
```
Always revoke immediately after publishing:
```bash
az role assignment delete \
  --assignee "{user_email}" \
  --role "Template Spec Contributor" \
  --scope "/subscriptions/{sub}/resourceGroups/{rg}"
```

## Repo structure (platform-microsoft-365)
- Template spec JSON: `catalog/template-spec/{version}/`
- ARM templates: `catalog/arm-templates/v{version}/`
- CSE scripts: `modules/azure/tenant_resources/custom_scripts/v{version}/`
- Subscription: `8eb6a56e-e1af-430a-9eec-2f4d436eb23c`
- Template spec RG: `eus2-tenant-shared-templates-rg`
- Storage account: `eus2bpctenantlibraryst`
- ARM blob container: `arm-templates`
- CSE blob container: `custom-script-extensions`

## Adding a new OS version to template specs
In each marketplace template spec JSON, find the `marketplace` variable object and add the new OS entry after the last existing one (e.g. after `redhat9`):
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
Also add the OS key to the `image` parameter's `allowedValues` array.
Gallery-only specs (`snapagent_farm_gallery`, `snapagent_multiplevm_pool_gallery`) do NOT get marketplace entries.

## Common errors
| Error | Cause | Fix |
|-------|-------|-----|
| `InvalidContentLink` | ARM template or CSE missing from blob storage | Run blob sync for the version |
| `AuthorizationFailed` on `templateSpecs/write` | No Template Spec Contributor role | Grant RBAC temporarily |
| Deployment uses wrong nested template | `template_version` variable mismatch | Check `TemplateVersion` allowedValues in the spec JSON |
