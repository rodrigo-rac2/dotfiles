---
name: diagnose-deployment
description: Use when an Azure VM deployment from a Template Spec fails, the user pastes a deployment error or JSON, asks why a deployment is failing, or encounters "InvalidContentLink", "StorageAccountNotFound", "AuthorizationFailed", or custom script extension errors. Also triggers on "deployment failed", "VM won't deploy", or "works on 1.6.0 but not 1.6.1".
allowed-tools: Bash, Read
---

# Diagnose Failed Azure Deployment

## Error → likely cause table

| Error | Likely cause |
|-------|-------------|
| `InvalidContentLink` | ARM template or CSE script missing from blob storage |
| VM created, provisioning fails | CSE script 404 — missing from blob |
| Works on v1.6.0, fails on v1.6.1 | Blob not synced for new version |
| `arm-templates` container appears empty | Wrong storage account — using `eus2bpcavlibraryst` instead of `eus2bpctenantlibraryst` |
| `AuthorizationFailed` on `templateSpecs/write` | Missing Template Spec Contributor RBAC |
| Windows deploys fine, Linux fails | `agent_linux/` CSE missing (was uploaded separately for Windows) |
| CSE fails with DNS `i/o timeout` | Parameter mismatch — `dns` IP is in a different spoke VNet than `environment` (see below) |

## Diagnosis steps for `InvalidContentLink`

### 1. Identify the expected version
Check what `TemplateVersion` was selected in the deployment. The spec constructs nested URLs like:
`https://eus2bpctenantlibraryst.blob.core.windows.net/arm-templates/v{version}/bpc_snapagent_vm_marketplace.json`

### 2. Check ARM templates in blob
```bash
az storage blob list \
  --account-name eus2bpctenantlibraryst \
  --container-name arm-templates \
  --prefix v{version}/ \
  --query "[].name" -o tsv
# Expected: 11 files for v1.6.x
```

### 3. Check CSE scripts in blob
```bash
az storage blob list \
  --account-name eus2bpctenantlibraryst \
  --container-name custom-script-extensions \
  --prefix v{version}/ \
  --query "[].name" -o tsv
# Expected: ~30 files across 13 subdirs
```

### 4. Check template spec is published
```bash
az ts show --name {spec_name} \
  --resource-group eus2-tenant-shared-templates-rg \
  --subscription 8eb6a56e-e1af-430a-9eec-2f4d436eb23c \
  --output json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['name'], d.get('versions',[]))"
```

### 5. Fix: upload missing files
- Missing ARM templates → `az storage blob upload-batch` to `arm-templates/v{version}/`
- Missing CSE → `az storage blob upload-batch` to `custom-script-extensions/v{version}/` (upload entire directory)

## Diagnosis steps for CSE DNS timeout

Error pattern:
```
dial tcp: lookup eus2bpctenantlibraryst.blob.core.windows.net on {DC_IP}:53: read udp ... i/o timeout
```

This means the blob file **exists** but the VM can't resolve it — DNS is unreachable.

### Get deployment parameters
```bash
az deployment group show \
  --resource-group {rg} --name {deployment_name} \
  --query "properties.parameters.{env:environment.value, dns:dns.value, domain:domain.value}" \
  -o json
```

### Check NIC DNS setting
```bash
az network nic show --ids {nic_id} \
  --query "{ip:ipConfigurations[0].privateIPAddress, dns:dnsSettings.dnsServers, subnet:ipConfigurations[0].subnet.id}" \
  -o json
```

**Root cause**: `environment` and `dns` parameters point to different VNets. Dev/qa/stg/prd/gwc are hub-spoke — they are NOT directly peered to each other. A VM in one spoke cannot reach a DC in another spoke.

**Fix**: Redeploy with matching parameters:
- `environment=qa` + `dns=10.212.0.10` (qa DC) — VM goes in qa VNet, can reach qa DC ✅
- `environment=dev` + `dns={dev DC IP}` — VM goes in dev VNet, can reach dev DC ✅
- `environment=dev` + `dns=10.212.0.10` — VM in dev, DC in qa → **spoke-to-spoke DNS timeout** ❌

## Common gotchas
- **`eus2bpcavlibraryst` vs `eus2bpctenantlibraryst`**: The AV storage account has an empty `arm-templates` container. Always use the tenant library account.
- **Partial CSE**: Uploading only `agent_linux/bpc_agent_cse.sh` is not enough. All 13 subdirectories must be present.
- **`v` prefix on blob paths**: Blob path is `v1.6.1/` not `1.6.1/` — the template spec variable includes the `v`.
- **Hub-spoke routing**: Hub is `10.210.0.0/16`. Spokes (dev `10.211`, qa `10.212`, stg `10.214`, prd `10.215`, gwc `10.216`) peer to hub only — no direct spoke-to-spoke routing.
