---
name: manual-test-trigger-m365-compassone
description: Triggers M365 events on a connected Azure AD tenant to set up test
  preconditions for CompassOne notification testing. Supports User Locked Out
  (multiple failed logins), and is extensible to other CLOUD_RESPONSE_M365
  event types. Use when reproducing notification bugs (e.g., TS-3319) or
  verifying that M365 notification rules fire correctly.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Trigger M365 Events — Test Precondition Setup

Trigger real M365 events on a connected Azure AD tenant so that CompassOne
notification rules can be verified end-to-end (event → Elastic ingestion →
notification engine → email delivery).

## What This Skill Does

1. **Identifies the target tenant**: finds the Azure tenant and primary domain
   connected to the test account
2. **Enumerates users**: lists real Azure AD users in the tenant to use as
   lockout targets
3. **Triggers the event**: runs a Node.js script to send repeated failed auth
   requests to the Azure AD OAuth endpoint, causing the target account to lock
4. **Confirms ingestion**: polls or inspects Kibana/Elastic to verify the event
   arrived in the CLOUD_RESPONSE_M365 dataset
5. **Reports outcome**: confirms event confirmed or timed out

## How to Use

```
> Trigger a User Locked Out event for the cloudresponse.dev M365 tenant
> Lock jpromanzio@cloudresponse.dev to test the notification rule
> Set up preconditions for TS-3319 reproduction on staging
```

## Prerequisites

### Azure CLI (for user enumeration)

```bash
# Check if logged in
az account show

# Log in as service principal (cloudresponse.dev)
az login --service-principal \
  --username 8dcc77c5-18bf-4ff4-a669-121ebfd3b1bf \
  --password "$(node -e "require('dotenv').config({path:'config/.env'}); console.log(process.env.CW_STAGING_PRIVATE_KEY || '')")" \
  --tenant 2633c608-9ca5-4e45-80d4-f19bc49d9e17 \
  --allow-no-subscriptions

# Or log in interactively as rcosta
az login --tenant 33a35c28-bd61-4d7d-8a6c-caf9084beca4
```

### Known Azure Tenants

| Domain                             | Tenant ID                              | Ingestion Speed           | Notes                    |
| ---------------------------------- | -------------------------------------- | ------------------------- | ------------------------ |
| cloudresponse.dev                  | `2633c608-9ca5-4e45-80d4-f19bc49d9e17` | Near real-time (~minutes) | Preferred for testing    |
| blackpointcyberdev.onmicrosoft.com | `33a35c28-bd61-4d7d-8a6c-caf9084beca4` | 3+ hours on staging       | Avoid for fast iteration |

## Step 1: Find the Target Tenant

### Via CompassOne API

```bash
# Get M365 packages for the test account (ABC Bank = 2b0b45b4-2f78-40bd-8c63-e61fa58661ff)
ENV=staging node -e "
require('dotenv').config({ path: 'config/.env.staging' });
require('dotenv').config({ path: 'config/.env' });

const accountId = '2b0b45b4-2f78-40bd-8c63-e61fa58661ff';
const baseUrl = process.env.C1_ENVIRONMENT.replace('compassone', 'co');

fetch(baseUrl + '/v1/cloud/ms365/account/' + accountId + '/packages', {
  headers: {
    'x-api-key': process.env.API_KEY_STG,
    'x-account-id': accountId,
  }
}).then(r => r.json()).then(d => {
  d.data?.forEach(p => console.log(p.tenantId, p.primaryDomain, p.id));
});
"
```

### Known Test Connection (Staging)

- **Account**: ABC Bank (`2b0b45b4-2f78-40bd-8c63-e61fa58661ff`)
- **Tenant**: cloudresponse.dev (`2633c608-9ca5-4e45-80d4-f19bc49d9e17`)
- **Connection ID**: `1630d276-b2fb-450f-9f42-cfdc1a9fe431`
- **Customer ID**: `c61512bf-1028-423a-bea2-29586f4d213e`

## Step 2: Enumerate Users in the Tenant

```bash
# List all users in cloudresponse.dev tenant
az account set --subscription 38fbc158-d1f1-4ba5-9d6d-5366450af955
az ad user list --output table --query "[].{UPN:userPrincipalName, Display:displayName}"
```

### Known cloudresponse.dev Users

| UPN                          | Display Name   | Notes                    |
| ---------------------------- | -------------- | ------------------------ |
| jpromanzio@cloudresponse.dev | Juan Promanzio | Used for lockout testing |
| lmineiro@cloudresponse.dev   | (Luis Mineiro) | Used for lockout testing |

## Step 3: Trigger User Locked Out Event

Send 15+ failed login attempts against the Azure AD OAuth endpoint. The account
locks after 10 failures (error `50053`); 15 ensures it locks reliably.

```javascript
// Save as /tmp/lockout.mjs and run: node /tmp/lockout.mjs
const username = 'jpromanzio@cloudresponse.dev';
const tenantId = '2633c608-9ca5-4e45-80d4-f19bc49d9e17';
const attempts = 15;

for (let n = 1; n <= attempts; n++) {
  const body = new URLSearchParams({
    grant_type: 'password',
    client_id: '04b07795-8ddb-461a-bbee-02f9e1bf7b46', // Azure CLI client ID (public)
    username,
    password: 'WrongPass_' + n + '_!',
    scope: 'openid',
  });

  const res = await fetch(
    `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`,
    { method: 'POST', body },
  );
  const data = await res.json();
  const code = data.error_codes?.[0];

  // 50126 = wrong password (user exists, not locked yet)
  // 50053 = account locked
  // 50034 = user not found
  console.log(
    `Attempt ${n}: ${code} — ${data.error_description?.split('\r')[0]}`,
  );

  if (code === 50053) {
    console.log('LOCKED after', n, 'attempts');
    break;
  }
  if (code === 50034) {
    console.error('User not found — check username');
    break;
  }
}
```

Run it:

```bash
node /tmp/lockout.mjs
```

Expected output:

```
Attempt 1: 50126 — AADSTS50126: Error validating credentials due to invalid username or password.
...
Attempt 10: 50053 — AADSTS50053: IdsLocked
LOCKED after 10 attempts
```

## Step 4: Confirm Ingestion in Elastic/Kibana

After triggering, wait 2–5 minutes (cloudresponse.dev) then check Kibana:

```
Index: logs-*
Filter: dataset = CLOUD_RESPONSE_M365
Filter: event.action = "User Locked Out - Multiple Failed Logins"
Filter: user.name = jpromanzio@cloudresponse.dev
Time range: last 15 minutes
```

Or via API:

```bash
# Check events via CompassOne API (if available)
# Alternatively, review Kibana at the staging Elastic cluster
```

## Step 5: Unlock Users (Cleanup)

After testing, unlock the locked accounts to avoid leaving them in a broken state:

```bash
# Unlock via Azure CLI
az account set --subscription 38fbc158-d1f1-4ba5-9d6d-5366450af955
az ad user update --id jpromanzio@cloudresponse.dev --account-enabled true

# Or via Azure Portal: Azure AD > Users > select user > Reset password / Unlock
```

## Supported Event Types

| Event                                    | Trigger Method           | Error Code  |
| ---------------------------------------- | ------------------------ | ----------- |
| User Locked Out - Multiple Failed Logins | 15 failed OAuth requests | AADSTS50053 |

## Known Issues

- **C1-6574** (staging): Global M365 notifications do not deliver emails on staging
  even when events are confirmed in Elastic. Event ingestion ≠ notification delivery.
  The notification engine pipeline appears broken on staging for this event type.

## Related Skills

- `manual-ui-test` — Navigate to Notifications page to create/verify notification rules
- `mcp-page-explorer` — Inspect the Notifications UI for locator generation
