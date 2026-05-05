---
name: check-notification-blackpoint
description:
  Check if a notification rule and email channel exist for a given detection type
  on a CompassOne account (staging or prod). Use before running detection tests
  to verify the notification pipeline will deliver alerts. Accepts a detection name,
  trigger label, or Jira ticket.
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# Check Notification — Blackpoint CompassOne

Verifies that a notification rule + email channel exist for a specific detection type,
so that when the detection fires, an email is actually sent.

## Arguments

- `/check-notification-blackpoint Mass Download` — check by detection name
- `/check-notification-blackpoint C1-6716` — extract detection type from ticket
- `/check-notification-blackpoint --list` — list all notifications and channels

## API Config

```bash
# Staging (default)
API_KEY="bpc_d28ea0a18bdab4a389faf3191e01ecbdaaa024095de9b13ddef531e5e973e197"
ACCOUNT_ID="2b0b45b4-2f78-40bd-8c63-e61fa58661ff"  # ABC Bank
BASE="https://co.staging-gold.snap.bpcybercloud.com"

# Prod (only if explicitly requested)
# API_KEY="bpc_610fa439c05549f40b4765066f93f8808f90c7f006f3f6c626095cebdec85488"
# BASE="https://co.blackpointcyber.com"
```

## Workflow

### Step 1: Identify the detection type

If a Jira ticket is provided, fetch it and extract the detection type from the summary.
Map the detection type to a trigger label (see trigger table below).

### Step 2: List all triggers and find the matching trigger ID

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

Search the output for the detection type. Common mappings:

| Detection | Trigger Label |
|---|---|
| Mass Download | Mass Download by a Single User |
| Unusual File Download | Unusual File Download Activity |
| Unusual File Deletion | Unusual File Deletion Activity |
| Unusual File Sharing | Unusual File Share Activity |
| Impossible Travel | Impossible Travel |
| User Locked Out | User Locked Out - Multiple Failed Logins |
| Login from Unapproved Country | Login from Unapproved Country |

If the trigger label doesn't match exactly, use a fuzzy match (case-insensitive substring).

### Step 3: List all notifications and check for a matching one

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

For each notification, get details to check the trigger:

```bash
curl -s "$BASE/v1/notifications/<NOTIFICATION_ID>" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Name:', d.get('name'))
print('Enabled:', d.get('enabled'))
print('Scope:', d.get('scope'))
trigger = d.get('trigger', {})
print('Trigger ID:', trigger.get('id'))
print('Trigger Label:', trigger.get('label'))
print('Channels:')
for c in d.get('channels', []):
    emails = c.get('settings', {}).get('emails', c.get('settings', {}).get('url', '?'))
    print(f'  - {c[\"name\"]} | {c[\"type\"]} | {emails}')
"
```

### Step 4: Report results

Report one of:

**READY** - Notification exists, is enabled, has the right trigger, and has at least one email channel.
Example: "Notification 'Rodrigo's Mass Download' is enabled with trigger 'Mass Download by a Single User' and routes to rcosta+mass-download@blackpointcyber.com"

**MISSING NOTIFICATION** - No notification rule exists for this trigger. Suggest running `/create-notification-blackpoint <detection-type>` to create one.

**DISABLED** - Notification exists but is disabled. Offer to enable it.

**NO CHANNEL** - Notification exists but has no email channel attached. Suggest adding one.

### Step 5: List channels (for context)

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
