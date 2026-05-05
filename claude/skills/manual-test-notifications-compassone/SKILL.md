---
name: manual-test-notifications-compassone
description:
  Manages CompassOne global notification channels (email/webhook) and notification
  rules via the API. Can create, validate, and update channels and notifications
  for any account on staging or prod. Use when setting up test preconditions for
  notification testing, verifying a channel or rule exists, or adding a channel
  to an existing notification.
allowed-tools:
  - Read
  - Bash
---

# Manual Test — Notifications Setup

Create, validate, and manage CompassOne global notification channels and
notification rules via the API. All operations use `curl` against the
Global Notifications Service.

## How to Use

```
> Create an email channel for rcosta+alerts@blackpointcyber.com in ABC Bank staging
> Check if a notification for "User Locked Out - Multiple Failed Logins" exists
> Add a webhook channel https://webhook.site/abc123 to the existing M365 lockout notification
> Validate that channel "rcosta multiple-failed-logins" is linked to the lockout notification
```

---

## API Config

```bash
# Load from env files
API_KEY="bpc_d28ea0a18bdab4a389faf3191e01ecbdaaa024095de9b13ddef531e5e973e197"  # staging
ACCOUNT_ID="2b0b45b4-2f78-40bd-8c63-e61fa58661ff"  # ABC Bank (staging)
BASE="https://co.staging-gold.snap.bpcybercloud.com"  # staging API base
```

For prod:

```bash
API_KEY="bpc_610fa439c05549f40b4765066f93f8808f90c7f006f3f6c626095cebdec85488"
BASE="https://co.blackpointcyber.com"
```

All requests require:

- `Authorization: $API_KEY`
- `x-account-id: $ACCOUNT_ID`
- `Content-Type: application/json` (for POST/PATCH)

---

## Known Resources (Staging / ABC Bank)

### Channels

| ID                                     | Name                          | Type    | Destination                                       |
| -------------------------------------- | ----------------------------- | ------- | ------------------------------------------------- |
| `3b467a3b-81dc-46f0-8e64-cc5e12481ab6` | Rodrigo's email               | EMAIL   | rcosta@blackpointcyber.com                        |
| `00eb5133-9062-4e6e-b80c-8645640612f4` | rcosta multiple-failed-logins | EMAIL   | rcosta+multiple-failed-logins@blackpointcyber.com |
| `e4ab2ca3-9426-4b25-9a96-6b55159cf86e` | erik email channel            | EMAIL   | ewitkowski@blackpointcyber.com                    |
| `2b3bd373-6343-433a-97d0-f3db9baa2716` | Rodrigo's webhoot.site        | WEBHOOK | webhook.site                                      |

### Notifications

| ID                                     | Name                                          | Trigger                                  | Enabled |
| -------------------------------------- | --------------------------------------------- | ---------------------------------------- | ------- |
| `52f0a0a6-350d-4c41-b0d7-48a635c91c78` | Rodrigo's User Locked Out - CloudResponse.dev | User Locked Out - Multiple Failed Logins | true    |

### Key Trigger IDs (CLOUD_RESPONSE_M365)

| Trigger ID                             | Label                                       |
| -------------------------------------- | ------------------------------------------- |
| `f706eb30-3bf1-4a62-b058-0f2631e9030f` | User Locked Out - Multiple Failed Logins    |
| `5c2ca367-c63f-421b-936a-fdda98093ed6` | Impossible Travel                           |
| `7ce95d32-f83d-49fd-936e-f4207a619117` | External Email Forwarding Rule Created      |
| `f2025d6b-8cce-4707-9bfd-6af7b3a86472` | New MFA Device Added                        |
| `e446d454-e17c-48b8-bfe1-570feb2faab7` | Login from Unapproved Country               |
| `d0e65244-99d3-4ea2-a2cb-2d5dd54592ea` | User Consented to Unverified Enterprise App |

To get all 48 triggers: `GET /v1/triggers` (see Step: List Triggers below).

---

## Step: List All Channels

```bash
curl -s "$BASE/v1/channels?page=1&pageSize=50&sortBy=name&sortOrder=ASC" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for c in d.get('data', []):
    emails = c.get('settings',{}).get('emails', c.get('settings',{}).get('url','?'))
    print(c['id'], '|', c['type'], '|', c['name'], '|', emails)
"
```

## Step: List All Notifications

```bash
curl -s "$BASE/v1/notifications?page=1&pageSize=50&sortBy=name&sortOrder=ASC" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for n in d.get('data', []):
    print(n['id'], '|', n['name'], '| enabled:', n.get('enabled'))
"
```

## Step: Get Notification Details (channels + trigger)

```bash
NOTIFICATION_ID="<notification-uuid>"
curl -s "$BASE/v1/notifications/$NOTIFICATION_ID" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Name:', d.get('name'))
print('Enabled:', d.get('enabled'))
print('Scope:', d.get('scope'))
print('Trigger:', d.get('trigger', {}).get('label'))
print('Channels:')
for c in d.get('channels', []):
    print(' -', c['name'], '|', c.get('settings', {}).get('emails', c.get('settings', {}).get('url')))
"
```

## Step: List All Triggers

```bash
curl -s "$BASE/v1/triggers" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
triggers = json.load(sys.stdin)
if isinstance(triggers, dict): triggers = triggers.get('data', [])
for t in sorted(triggers, key=lambda x: x.get('label','')):
    print(t['id'], '|', t['source'], '|', t['label'])
"
```

---

## Step: Create Email Channel

```bash
EMAIL="rcosta+alerts@blackpointcyber.com"
NAME="rcosta alerts"

curl -s -X POST "$BASE/v1/channels" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"enabled\": true,
    \"name\": \"$NAME\",
    \"type\": \"EMAIL\",
    \"settings\": {
      \"type\": \"EMAIL\",
      \"emails\": [\"$EMAIL\"]
    }
  }" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Created channel:', d.get('id'), d.get('name'), d.get('settings', {}).get('emails'))
"
```

## Step: Create Webhook Channel

```bash
WEBHOOK_URL="https://webhook.site/your-uuid"
NAME="my webhook channel"

curl -s -X POST "$BASE/v1/channels" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"enabled\": true,
    \"name\": \"$NAME\",
    \"type\": \"WEBHOOK\",
    \"settings\": {
      \"type\": \"WEBHOOK\",
      \"url\": \"$WEBHOOK_URL\"
    }
  }" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Created channel:', d.get('id'), d.get('name'), d.get('settings', {}).get('url'))
"
```

---

## Step: Create Notification Rule

```bash
TRIGGER_ID="f706eb30-3bf1-4a62-b058-0f2631e9030f"  # User Locked Out - Multiple Failed Logins
CHANNEL_IDS='["00eb5133-9062-4e6e-b80c-8645640612f4"]'  # array of channel UUIDs
NAME="My Lockout Notification"
SCOPE="GLOBAL"  # or "SPECIFIC" (requires tenantIds)

curl -s -X POST "$BASE/v1/notifications" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$NAME\",
    \"enabled\": true,
    \"scope\": \"$SCOPE\",
    \"triggerId\": \"$TRIGGER_ID\",
    \"channelIds\": $CHANNEL_IDS
  }" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Created notification:', d.get('id'), d.get('name'))
"
```

For a SPECIFIC tenant scope:

```bash
# Add tenantIds to the payload:
# \"tenantIds\": [\"c61512bf-1028-423a-bea2-29586f4d213e\"]
```

---

## Step: Add Channel to Existing Notification

Get the current channels first, then include them all in the PATCH:

```bash
NOTIFICATION_ID="52f0a0a6-350d-4c41-b0d7-48a635c91c78"
# Replace with the full list of channel IDs you want (existing + new)
CHANNEL_IDS='["3b467a3b-81dc-46f0-8e64-cc5e12481ab6", "00eb5133-9062-4e6e-b80c-8645640612f4"]'

curl -s -X PATCH "$BASE/v1/notifications/$NOTIFICATION_ID" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d "{\"channelIds\": $CHANNEL_IDS}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Updated:', d.get('name'))
for c in d.get('channels', []):
    print(' -', c['name'], c.get('settings',{}).get('emails', c.get('settings',{}).get('url')))
"
```

---

## Step: Validate Channel Exists

Check if a channel with a given email/URL already exists before creating:

```bash
TARGET_EMAIL="rcosta+multiple-failed-logins@blackpointcyber.com"

curl -s "$BASE/v1/channels?page=1&pageSize=100&sortBy=name&sortOrder=ASC" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
target = '$TARGET_EMAIL'
d = json.load(sys.stdin)
found = [c for c in d.get('data', [])
         if target in c.get('settings',{}).get('emails',[])
         or target == c.get('settings',{}).get('url','')]
if found:
    for c in found:
        print('FOUND:', c['id'], c['name'], c.get('settings'))
else:
    print('NOT FOUND — safe to create')
"
```

## Step: Validate Notification Exists

Check if a notification with a given trigger is already configured:

```bash
TRIGGER_ID="f706eb30-3bf1-4a62-b058-0f2631e9030f"

curl -s "$BASE/v1/notifications?page=1&pageSize=50" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
target_trigger = '$TRIGGER_ID'
# List endpoint doesn't embed trigger details — use GET by ID for each or check name
for n in d.get('data', []):
    print(n['id'], n['name'], 'enabled:', n.get('enabled'))
"
# Then GET each notification by ID if needed to check trigger
```

Or get notification details directly by ID if you already know it:

```bash
curl -s "$BASE/v1/notifications/52f0a0a6-350d-4c41-b0d7-48a635c91c78" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -m json.tool
```

---

## Validation Checklist

After creating/updating, verify:

- [ ] Channel appears in `GET /v1/channels` with correct email/URL
- [ ] Notification details show channel in `channels[]` array
- [ ] Notification `enabled: true`
- [ ] Trigger label matches expected event type

---

## Related Skills

- `manual-test-trigger-m365` — Trigger M365 events to test notification delivery end-to-end
- `manual-test-ui-test` — Navigate to the Notifications UI to verify visually
- `manual-test-onboard-m365` — Onboard the M365 connection before notifications can fire
