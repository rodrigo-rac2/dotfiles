---
name: manual-test-onboard-m365-compassone
description:
  Onboards (or re-onboards) a Microsoft 365 tenant connection in CompassOne
  staging or prod. Handles the full 8-step wizard: domain verification, Azure
  AD admin consent, Global Administrator role assignment via Graph API, auditing,
  webhooks, policy sync, and finish. Also covers removing an existing broken
  connection and cleaning up stale Azure service principals before re-onboarding.
  Uses playwright-cli for browser automation and Azure CLI / Graph API for SP
  management.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_click
  - mcp__playwright__browser_snapshot
  - mcp__playwright__browser_screenshot
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_evaluate
  - mcp__playwright__browser_wait_for
  - mcp__playwright__browser_type
  - mcp__playwright__browser_fill_form
  - mcp__playwright__browser_close
---

# Onboard M365 — Microsoft 365 Tenant Connection Setup

Perform a full Microsoft 365 onboarding (or re-onboarding) for a CompassOne
account/tenant. Covers the 8-step CompassOne wizard plus Azure AD service
principal management via Graph API.

## How to Use

```
> Onboard cloudresponse.dev M365 connection for ABC Bank on staging
> Re-onboard the M365 connection — the old one is broken
> Remove and redo the Microsoft 365 integration for ABC Bank
```

## Known Test Account (Staging)

| Field           | Value                                  |
| --------------- | -------------------------------------- |
| Account         | ABC Bank                               |
| Account ID      | `2b0b45b4-2f78-40bd-8c63-e61fa58661ff` |
| Customer ID     | `c61512bf-1028-423a-bea2-29586f4d213e` |
| M365 Domain     | `cloudresponse.dev`                    |
| Azure Tenant ID | `2633c608-9ca5-4e45-80d4-f19bc49d9e17` |
| Azure Admin     | `rcosta@cloudresponse.dev`             |

## Overview

The onboarding has two phases:

1. **Azure Cleanup** (if re-onboarding) — delete stale service principals from
   the M365 tenant so the wizard creates fresh ones
2. **CompassOne Wizard** (8 steps) — browser automation through the setup flow,
   with Graph API used to assign the Global Administrator role at step 3

---

## Phase 1: Remove Old Connection & Clean Up Azure SPs

### Step 1A: Delete Existing CompassOne Connection (if any)

```
Navigate to:
  Manage Tenant → (select tenant sidebar) → Integrations tab → Microsoft 365 → Setup tab
  URL: /accounts/{accountId}/tenants/{customerId}/integrations/cloud-response-m365/overview?tab=setup

Click "Delete Connection" → confirm deletion
```

Or go directly to Setup tab:

```
https://compassone.staging.snap.bpcybercloud.com/accounts/2b0b45b4-2f78-40bd-8c63-e61fa58661ff/tenants/c61512bf-1028-423a-bea2-29586f4d213e/integrations/cloud-response-m365/overview?tab=setup
```

### Step 1B: Delete Stale Service Principals from Azure AD

Log into the M365 Azure tenant:

```bash
# Interactive login (device code — user must authenticate in browser)
az login --use-device-code --tenant 2633c608-9ca5-4e45-80d4-f19bc49d9e17 --allow-no-subscriptions

# Or switch if already logged in
az account set --subscription "Azure subscription 1"
```

Find and delete the Blackpoint service principals:

```bash
# Find all Blackpoint/BPC service principals
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals?\$search=\"displayName:Cloud Response\"&\$select=id,displayName,createdDateTime" \
  --headers "ConsistencyLevel=eventual" -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for sp in data['value']:
    print(sp['createdDateTime'], sp['id'], sp['displayName'])
"

az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals?\$search=\"displayName:bpc\"&\$select=id,displayName,createdDateTime" \
  --headers "ConsistencyLevel=eventual" -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for sp in data['value']:
    print(sp['createdDateTime'], sp['id'], sp['displayName'])
"
```

Delete each stale SP (keep unrelated ones like `Blackpoint Managed Defender for Endpoint`):

```bash
for SP_ID in "<id1>" "<id2>"; do
  NAME=$(az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID?\$select=displayName" -o tsv --query displayName)
  echo "Deleting: $NAME ($SP_ID)"
  az rest --method DELETE --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID"
done
```

**Known SPs to delete for cloudresponse.dev re-onboarding:**

- `Blackpoint Cloud Response` — main M365 integration app
- `bpc_staging_app` — staging integration app

**Do NOT delete:**

- `Blackpoint Managed Defender for Endpoint`
- `Cloud Response Dev` / `Cloud Response Credentials Rotator`

---

## Phase 2: CompassOne M365 Onboarding Wizard

### Login to CompassOne

```bash
# Launch headed browser
playwright-cli open --headed "https://compassone.staging.snap.bpcybercloud.com/login?use-password-internal=true" &
sleep 3
```

**CRITICAL — SSO Bypass Rule:**

- `qaautomatedusersa@blackpointcyber.com` has no `+` alias → MUST use `?use-password-internal=true`
- Without this param the login page freezes on "Log in to get started" and does nothing

Login sequence:

```bash
playwright-cli snapshot   # get element refs
playwright-cli fill e18 "qaautomatedusersa@blackpointcyber.com"  # ref may vary
playwright-cli click e19  # "Log in to Blackpoint" button

# Wait for password page, then:
playwright-cli fill e23 "Qa03112025!"
playwright-cli click e28  # "Continue"

# Wait for MFA page, generate TOTP, then:
TOTP=$(SECRET="MJWDEU3JKYWCUQSEHIWDAOSSJRXGGVZX" node -e "
const OTPAuth = require('./node_modules/otpauth');
const totp = new OTPAuth.TOTP({ digits: 6, period: 30, algorithm: 'SHA1', secret: OTPAuth.Secret.fromBase32(process.env.SECRET) });
console.log(totp.generate());
")
playwright-cli fill e19 "$TOTP"  # MFA input ref (re-snapshot if needed)
playwright-cli click e21  # "Continue"
```

### Navigate to Manage Tenant → M365 Integration

After login, go to the M365 integration setup:

```bash
playwright-cli eval "window.location.href = 'https://compassone.staging.snap.bpcybercloud.com/accounts/2b0b45b4-2f78-40bd-8c63-e61fa58661ff/tenants/c61512bf-1028-423a-bea2-29586f4d213e/security-posture-rating'"
sleep 3

# Click "Manage Tenant" in sidebar, then navigate to M365
playwright-cli snapshot  # find "Manage Tenant" link ref
playwright-cli click e156  # ref varies — check snapshot
```

Or navigate directly to the M365 integration page:

```bash
playwright-cli eval "window.location.href = 'https://compassone.staging.snap.bpcybercloud.com/accounts/2b0b45b4-2f78-40bd-8c63-e61fa58661ff/tenants/c61512bf-1028-423a-bea2-29586f4d213e/integrations/cloud-response-m365/overview?from=tenant-settings'"
sleep 4
```

Click the "Setup" tab:

```bash
playwright-cli snapshot  # find tab "Setup" ref
playwright-cli click e234  # ref varies
```

### Step 1: Verify Connection Domain

```bash
playwright-cli snapshot  # find textbox "Microsoft Connection Domain"
playwright-cli fill e382 "cloudresponse.dev"
playwright-cli click e383  # "Check Domain" button
sleep 5
```

Expected: advances to step 2 "Grant Permissions"

### Step 2: Grant Permissions (Azure AD Admin Consent)

```bash
playwright-cli snapshot  # find "Sign in & Grant Permissions" button
playwright-cli click e461  # ref varies
sleep 5
```

This opens the Azure AD consent page (`login.microsoftonline.com`).

Fill Azure AD credentials:

```bash
playwright-cli snapshot  # find email textbox
playwright-cli fill e28 "rcosta@cloudresponse.dev"
playwright-cli click e38   # "Next"
sleep 4
# USER MUST TYPE PASSWORD MANUALLY in the browser window
# OR read from a secure source — not stored in config/.env
```

After password + any MFA, Azure shows "Permissions requested" screen:

```bash
playwright-cli snapshot  # find "Accept" button
playwright-cli click e150  # "Accept"
sleep 6
```

Expected: redirects back to CompassOne, advances to step 3 "Enable App Permissions"

### Step 3: Enable App Permissions (Assign Global Administrator)

**This step requires assigning the Global Administrator directory role to the
newly created service principal via the Graph API.**

Find the new SP (created at consent time):

```bash
az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals?\$search=\"displayName:Cloud Response Staging\"&\$select=id,displayName,createdDateTime" \
  --headers "ConsistencyLevel=eventual" -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for sp in sorted(data['value'], key=lambda x: x.get('createdDateTime',''), reverse=True):
    print(sp['createdDateTime'], sp['id'], sp['displayName'])
"
```

The new SP will be the one with the most recent `createdDateTime`.

Assign Global Administrator role:

```bash
NEW_SP_ID="<id-from-above>"

# Get Global Administrator role object ID
GA_ROLE_ID=$(az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/directoryRoles?\$filter=roleTemplateId eq '62e90394-69f5-4237-9190-012177145e10'&\$select=id" \
  -o json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['value'][0]['id'])")

echo "Assigning GA role $GA_ROLE_ID to SP $NEW_SP_ID"

az rest \
  --method POST \
  --url "https://graph.microsoft.com/v1.0/directoryRoles/$GA_ROLE_ID/members/\$ref" \
  --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/$NEW_SP_ID\"}"

# Verify
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$NEW_SP_ID/memberOf?\$select=displayName" \
  -o json | python3 -c "import json,sys; [print('✓', r['displayName']) for r in json.load(sys.stdin)['value']]"
```

Back in CompassOne, click "Verify App Permissions":

```bash
playwright-cli snapshot  # find "Verify App Permissions" button
playwright-cli click e145  # ref varies
sleep 10
```

### Steps 4–6: Automated (Enable Auditing, Register Webhooks, Sync Policies)

These steps run automatically after step 3 passes. Monitor progress:

```bash
# Poll every 20s until reaching Add Exclusion Groups or Complete Onboarding
for i in {1..20}; do
  playwright-cli screenshot
  sleep 20
  LATEST=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)
  if [ -n "$LATEST" ] && grep -qi "exclusion\|finish\|complete" "$LATEST"; then
    echo "Reached final step"
    break
  fi
done
```

Each step can take up to 15 minutes, but usually completes in under 1 minute.

### Step 7: Add Exclusion Groups (Optional)

Skip unless needed:

```bash
playwright-cli snapshot  # find "Finish Integration" button
playwright-cli click e206  # ref varies
sleep 5
```

### Step 8: Complete Onboarding

After clicking "Finish Integration", a modal appears:

```
✓ Creation Complete
Status: Active
Type: Microsoft 365
Domain: cloudresponse.dev
```

Click "Go to Integration" to confirm the connection is Active.

---

## Verify the Connection is Working

After onboarding, trigger a test event to confirm end-to-end:

```bash
# Trigger a user lockout on cloudresponse.dev to generate a CLOUD_RESPONSE_M365 event
# See trigger-m365-events skill for full details
```

Then check if the staging notification email arrives (allow 5–10 minutes).

---

## Navigation Reference

| Destination                  | URL Pattern                                                                                                 |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Manage Tenant                | `/accounts/{accountId}/tenants/{customerId}/security-posture-rating` then click "Manage Tenant" in sidebar  |
| M365 Integration (Overview)  | `/accounts/{accountId}/tenants/{customerId}/integrations/cloud-response-m365/overview?from=tenant-settings` |
| M365 Integration (Setup tab) | Same URL + `?tab=setup`                                                                                     |
| Manage Account               | `/accounts/{accountId}/settings/manage-account`                                                             |
| Account Integrations         | `/accounts/{accountId}/settings/integrations` (PSA integrations only — NOT M365)                            |

**Note:** M365 is under **Manage Tenant → Integrations**, NOT under
**Manage Account → Integrations** (which only shows PSA tools like ConnectWise).

---

## Troubleshooting

### Login freezes on "Log in to get started"

- Missing `?use-password-internal=true` in the URL
- BSA account (`qaautomatedusersa@blackpointcyber.com`) always needs this bypass
- Fix: navigate to `https://compassone.staging.snap.bpcybercloud.com/login?use-password-internal=true`

### "Resume" button doesn't work on existing broken connection

- The Azure service principal is in a broken state
- Fix: delete the connection in CompassOne UI, delete the SPs from Azure AD, re-onboard from scratch

### Step 3 "Verify App Permissions" fails

- Global Administrator role not yet assigned to the new SP
- The role must be assigned via Graph API BEFORE clicking "Verify App Permissions"
- The UI button "Edit Global Administrator Roles" opens Azure Portal but is slow/unreliable
- Use the Graph API approach instead (see Step 3 above)

### Azure token expired after revokeSignInSessions

- Running `revokeSignInSessions` for a user revokes ALL their tokens, including the CLI session
- Fix: `az login --use-device-code --tenant {tenantId} --allow-no-subscriptions`

### Service principal not found by name

- Use `$search` with `ConsistencyLevel: eventual` header
- Or sort all SPs by `createdDateTime desc` and look for the most recent one

---

## Related Skills

- `trigger-m365-events` — Trigger M365 events (lockout, etc.) to test the connection end-to-end
- `manual-ui-test` — General CompassOne browser automation and login reference
- `mcp-page-explorer` — Explore page structure if CompassOne UI has changed
