---
name: create-notification-blackpoint
description:
  Create an email notification channel and notification rule for a detection type
  on a CompassOne account. Generates email address as rcosta+C1XXXX@blackpointcyber.com
  (or rcosta+<slug>@blackpointcyber.com) and wires it to the correct trigger.
  Use when /check-notification-blackpoint reports MISSING NOTIFICATION.
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# Create Notification — Blackpoint CompassOne

Creates an email channel and notification rule for a specific detection type,
routing alerts to `rcosta+<ticket>@blackpointcyber.com`.

## Arguments

- `/create-notification-blackpoint C1-6716` — creates channel + rule for the ticket's detection type
- `/create-notification-blackpoint "Mass Download" C1-6716` — explicit detection name + ticket for email tag
- `/create-notification-blackpoint "Unusual File Download" --email rcosta+custom@blackpointcyber.com` — custom email

## API Config

```bash
# Staging (default)
API_KEY="bpc_d28ea0a18bdab4a389faf3191e01ecbdaaa024095de9b13ddef531e5e973e197"
ACCOUNT_ID="2b0b45b4-2f78-40bd-8c63-e61fa58661ff"  # ABC Bank
BASE="https://co.staging-gold.snap.bpcybercloud.com"
```

## Workflow

### Step 1: Determine detection type and email

If a Jira ticket ID (e.g., `C1-6716`) is provided:
- Fetch the ticket to determine the detection type from the summary
- Use the ticket key to generate the email: `rcosta+C1-6716@blackpointcyber.com`

If a detection name is provided without a ticket:
- Slugify the name: `rcosta+unusual-file-download@blackpointcyber.com`

If `--email` is explicitly provided, use that email verbatim.

### Step 2: Find the trigger ID

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

Match the detection type to a trigger label (case-insensitive substring match).

Common mappings:

| Detection | Trigger Label |
|---|---|
| Mass Download | Mass Download by a Single User |
| Unusual File Download | Unusual File Download Activity |
| Unusual File Deletion | Unusual File Deletion Activity |
| Unusual File Sharing | Unusual File Share Activity |
| Impossible Travel | Impossible Travel |
| User Locked Out | User Locked Out - Multiple Failed Logins |

If no match is found, list all triggers and ask the user to pick.

### Step 3: Check if channel already exists

```bash
EMAIL="rcosta+C1-6716@blackpointcyber.com"

curl -s "$BASE/v1/channels?page=1&pageSize=100&sortBy=name&sortOrder=ASC" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
target = '$EMAIL'
d = json.load(sys.stdin)
found = [c for c in d.get('data', [])
         if target in c.get('settings',{}).get('emails',[])]
if found:
    for c in found:
        print('EXISTS:', c['id'], c['name'], c.get('settings'))
else:
    print('NOT_FOUND')
"
```

If channel exists, reuse its ID. Skip to Step 5.

### Step 4: Create email channel

```bash
EMAIL="rcosta+C1-6716@blackpointcyber.com"
NAME="rcosta C1-6716"

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
print('CHANNEL_ID=' + d.get('id', 'ERROR'))
print('Created channel:', d.get('name'), '→', d.get('settings', {}).get('emails'))
"
```

Save the `CHANNEL_ID` for the next step.

### Step 5: Check if notification rule already exists for this trigger

```bash
TRIGGER_ID="<from step 2>"

curl -s "$BASE/v1/notifications?page=1&pageSize=50" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for n in d.get('data', []):
    print(n['id'], '|', n['name'], '| enabled:', n.get('enabled'))
"
```

Then check each notification's trigger:

```bash
curl -s "$BASE/v1/notifications/<NOTIFICATION_ID>" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('trigger:', d.get('trigger', {}).get('id'), d.get('trigger', {}).get('label'))
print('channels:', [c['name'] for c in d.get('channels', [])])
"
```

If a notification already exists for this trigger:
- **Add the channel to the existing notification** using PATCH (see Step 6b)
- Do NOT create a duplicate notification

### Step 6a: Create notification rule (if no existing one)

```bash
TRIGGER_ID="<from step 2>"
CHANNEL_ID="<from step 4>"
NAME="Rodrigo's <Detection Label> - C1-XXXX"

curl -s -X POST "$BASE/v1/notifications" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$NAME\",
    \"enabled\": true,
    \"scope\": \"GLOBAL\",
    \"triggerId\": \"$TRIGGER_ID\",
    \"channelIds\": [\"$CHANNEL_ID\"]
  }" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Created notification:', d.get('id'), d.get('name'))
"
```

### Step 6b: Add channel to existing notification (if one already exists)

First, get existing channel IDs:

```bash
NOTIFICATION_ID="<existing notification id>"

EXISTING_CHANNELS=$(curl -s "$BASE/v1/notifications/$NOTIFICATION_ID" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ids = [c['id'] for c in d.get('channels', [])]
print(json.dumps(ids))
")
```

Then PATCH with all channels (existing + new):

```bash
NEW_CHANNEL_ID="<from step 4>"

curl -s -X PATCH "$BASE/v1/notifications/$NOTIFICATION_ID" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" \
  -H "Content-Type: application/json" \
  -d "{\"channelIds\": $(echo $EXISTING_CHANNELS | python3 -c "
import json, sys
ids = json.load(sys.stdin)
ids.append('$NEW_CHANNEL_ID')
print(json.dumps(ids))
")}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Updated:', d.get('name'))
for c in d.get('channels', []):
    print(' -', c['name'], c.get('settings',{}).get('emails', c.get('settings',{}).get('url')))
"
```

### Step 7: Confirm

After creation, verify the email address in the notification:

```bash
curl -s "$BASE/v1/notifications/$NOTIFICATION_ID" \
  -H "Authorization: $API_KEY" \
  -H "x-account-id: $ACCOUNT_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Notification:', d.get('name'))
print('Enabled:', d.get('enabled'))
print('Trigger:', d.get('trigger', {}).get('label'))
for c in d.get('channels', []):
    emails = c.get('settings', {}).get('emails', [])
    print(f'  Channel: {c[\"name\"]} → {emails}')
"
```

Report: "Notification '<name>' created with trigger '<label>' routing to `rcosta+C1-XXXX@blackpointcyber.com`"
