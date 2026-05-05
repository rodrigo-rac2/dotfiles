---
name: publish-template-specs
description: Use when the user wants to publish template spec JSON files to Azure Portal, run "az ts create", update a template spec version in Azure, or asks "how do I publish the template spec". Also triggers when the user says "push the template spec to Azure" or "update the portal with the new TS version".
allowed-tools: Bash, Read, Glob
---

# Publish Azure Template Specs

## Repo constants (platform-microsoft-365)
- Subscription: `8eb6a56e-e1af-430a-9eec-2f4d436eb23c`
- Resource group: `eus2-tenant-shared-templates-rg`
- Template spec JSON: `catalog/template-spec/{version}/`
- 9 deployed specs: `domain_controllers_stamp_gallery`, `domaincontroller_farm_stamp_marketplace`, `snapagent_farm_gallery`, `snapagent_farm_marketplace`, `snapagent_multiplevm_pool_gallery`, `snapagent_multiplevm_pool_marketplace`, `snapagent_osversions_stamp_gallery`, `snapagent_osversions_stamp_marketplace`, `snapagent_osversions_stamp_marketplace_dc`

## RBAC — self-grant pattern (always temporary)

`rcosta@blackpointcyberdev.onmicrosoft.com` has no write access by default. It has `User Access Administrator` at root, so it can self-grant roles temporarily.

**Always grant at subscription scope** (RG scope causes `LinkedAuthorizationFailed` for linked resources):
```bash
# Grant
az role assignment create \
  --assignee "rcosta@blackpointcyberdev.onmicrosoft.com" \
  --role "Template Spec Contributor" \
  --scope "/subscriptions/8eb6a56e-e1af-430a-9eec-2f4d436eb23c/resourceGroups/eus2-tenant-shared-templates-rg"

# Refresh token + wait for IAM propagation
az account get-access-token --resource https://management.azure.com -o none
sleep 60
```

**Always revoke immediately after:**
```bash
az role assignment delete \
  --assignee "rcosta@blackpointcyberdev.onmicrosoft.com" \
  --role "Template Spec Contributor" \
  --scope "/subscriptions/8eb6a56e-e1af-430a-9eec-2f4d436eb23c/resourceGroups/eus2-tenant-shared-templates-rg"
```

## RBAC roles by operation
| Operation | Role needed | Scope |
|-----------|-------------|-------|
| `az ts create` (publish/update) | `Template Spec Contributor` | RG |
| `az ts delete` | `Contributor` | RG (Template Spec Contributor does NOT include delete) |
| Subnet/network writes | `Contributor` | **Subscription** (RG scope insufficient) |

## Workflow

### 1. Check az CLI and login
```bash
az version || brew install azure-cli
az account show || az login
az account set --subscription 8eb6a56e-e1af-430a-9eec-2f4d436eb23c
```

### 2. Grant RBAC temporarily (see pattern above)

### 3. Publish each spec
```bash
az ts create \
  --name {spec_name} \
  --version {version} \
  --resource-group eus2-tenant-shared-templates-rg \
  --subscription 8eb6a56e-e1af-430a-9eec-2f4d436eb23c \
  --template-file catalog/template-spec/{version}/{spec_name}.json \
  --yes
```

### 4. Verify
```bash
az ts show --name {spec_name} --resource-group eus2-tenant-shared-templates-rg \
  --subscription 8eb6a56e-e1af-430a-9eec-2f4d436eb23c \
  --output json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['name'], d.get('versions', []))"
```

### 5. Revoke RBAC immediately after

## ⚠️ Publishing alone is not enough
After publishing, you must also upload ARM templates and CSE scripts to blob storage or deployments will fail with `InvalidContentLink`. See the `sync-blob` and `azure-three-way-sync` skills.
