---
name: manual-test-detection-compassone
description:
  Full detection test lifecycle for Blackpoint CompassOne MDR detections.
  Orchestrates Redis baseline clearing, event injection via apollo11, detection
  verification via CCS consumer logs and Elasticsearch, and optional UI
  confirmation in CompassOne Detections view. Use when testing detection logic
  changes, threshold adjustments, new detection types, or baseline behavior.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
  - Agent
  - AskUserQuestion
  - mcp__Atlassian-BPCyber-Token__jira_get_issue
  - mcp__Atlassian-BPCyber-Token__jira_add_comment
---

# Manual Detection Test - CompassOne MDR

End-to-end testing of MDR detection logic: precondition setup, event injection,
and multi-layer verification.

## When to Use

- Testing new detection types (e.g., C1-6307 unusual file activity)
- Testing detection threshold changes (e.g., C1-6716 sparse baselines)
- Testing baseline calculation behavior (e.g., C1-6306 rolling stats)
- Verifying suppression/opt-in behavior for detections
- Any ticket with `[MDR] [Detection]` in the summary

## Prerequisites

Before running any detection test, ensure:

```bash
# 1. Kafka port-forwarding (required for sending events)
kubectl port-forward -n ops deployment/confluent-proxy 30090 30091 30092 30093

# 2. kubectl access to staging cluster
kubectl get pods -n default | grep cloud-control

# 3. apollo11 repo built
cd /Users/rac2/blackpoint/repos/apollo11 && npm run build
```

### CRITICAL: Verify notification exists for the detection type

Before injecting events, **always** run `/check-notification-blackpoint <detection-type>`
to verify a notification rule with an email channel exists. Without this, detections
fire silently with no email confirmation.

If no notification exists, run `/create-notification-blackpoint <detection-type> C1-XXXX`
to create one routing to `rcosta+C1-XXXX@blackpointcyber.com`.

## Workflow

### Phase 1: Ticket Analysis

1. **Fetch the ticket** from Jira
2. **Identify the detection type** from the summary/description:
   - File activity detections: mass_download, unusual_file_download, unusual_file_deleted, unusual_file_sharing
   - Login detections: impossible_travel, login_from_new_device_and_ip, login_from_unapproved_country, user_locked_out
   - Admin detections: admin_consented_to_unverified_enterprise_app, role_assigned_to_user, etc.
   - Exchange detections: suspicious_inbox_rule_created, mailbox_access_granted, etc.
3. **Determine what changed**: threshold values, baseline logic, new detection type, suppression rules
4. **Extract test instructions** from the ticket description and comments (devs often include "How to test" sections)

### Phase 2: Precondition Setup

#### Staging Connection Details

Default test connection (cloudresponse.dev on staging):

| Field | Value |
|---|---|
| Package ID | `7a00f624-97b0-4f69-aa47-7c6e07ff320a` |
| Org ID | `2633c608-9ca5-4e45-80d4-f19bc49d9e17` |
| Email | `rcosta@cloudresponse.dev` |
| Site Org Name | `cloudresponse` |
| Account | ABC Bank (staging) |

To find package IDs for other connections:

```bash
kubectl exec -n default deployment/cloud-control-service -- node -e "
const { Client } = require('pg');
const client = new Client({
  host: process.env.POSTGRES_HOSTNAME,
  port: parseInt(process.env.POSTGRES_PORT),
  user: 'cloud_control_service_user',
  password: process.env.POSTGRES_STANDARD_PASSWORD,
  database: 'cloud_control_service',
  ssl: { rejectUnauthorized: false }
});
client.connect()
  .then(() => client.query(\"SELECT id, \\\"snapPackageId\\\", \\\"primaryDomain\\\" FROM ms365_defense_packages WHERE \\\"primaryDomain\\\" LIKE '%<DOMAIN>%' AND deleted IS NULL\"))
  .then(r => console.log(JSON.stringify(r.rows, null, 2)))
  .catch(e => console.error('ERR:', e.message))
  .finally(() => client.end());
"
```

#### Clear Redis Baseline (when testing baseline/threshold behavior)

For file activity detections, clear the `fileActivityDetector` keys in Redis DB 9.

**IMPORTANT**: The actual Redis key pattern is `@blackpointcyber/cloud-control-service:unique-events:*fileActivityDetector:*`,
NOT just `fileActivityDetector:*`. The Redis proxy is in the `ops` namespace and listens on port **36379** (not 6379).

**Recommended approach** — exec into CCS pod (auth + TLS handled automatically):

```bash
kubectl exec -n default deployment/cloud-control-service -- node -e "
const Redis = require('ioredis');
const redis = new Redis({
  host: process.env.REDIS_HOSTNAME,
  port: parseInt(process.env.REDIS_PORT),
  password: process.env.REDIS_PASSWORD,
  db: 9,
  tls: {}
});
redis.keys('*fileActivityDetector*').then(keys => {
  console.log('Found', keys.length, 'fileActivityDetector keys');
  if (keys.length > 0) {
    // Delete in batches of 100 to avoid argument overflow
    const batches = [];
    for (let i = 0; i < keys.length; i += 100) {
      batches.push(keys.slice(i, i + 100));
    }
    return batches.reduce((p, batch) => p.then(() => redis.del(...batch).then(d => console.log('Deleted batch:', d))), Promise.resolve());
  } else {
    console.log('No keys to delete — baseline is already clean');
  }
}).then(() => redis.quit()).catch(e => { console.error('ERR:', e.message); redis.quit(); });
"
```

**Alternative** — use cloud-control-service repo script:

```bash
# Port-forward to the CCS Redis proxy (ops namespace, port 36379)
kubectl port-forward -n ops deployment/elasticache-proxy-cloud-control-service 36379:36379

# Then from the cloud-control-service repo root:
node scripts/testing/remove-file-activity-keys.js --delete
```

### Phase 3: Event Injection via Apollo11

#### Using the test runner (file activity detections)

```bash
cd /Users/rac2/blackpoint/repos/apollo11

# List available scenarios
npm run test_unusual_file_activity

# Run a specific scenario
NODE_ENV=staging npm run test_unusual_file_activity -- --scenario spike-all

# Available scenarios:
#   spike-download       Baseline + 60 FileDownloaded      → ALERT expected
#   spike-deleted        Baseline + 60 FileDeleted         → ALERT expected
#   spike-sharing        Baseline + 60 SharingLinkCreated  → ALERT expected
#   spike-all            Baseline + 60 of each             → 3 ALERTs expected
#   no-alert-download    Baseline + 10 FileDownloaded      → NO alert
#   no-alert-deleted     Baseline + 10 FileDeleted         → NO alert
#   no-alert-sharing     Baseline + 10 SharingLinkCreated  → NO alert
#   boundary-download    Baseline + 50 (= threshold)       → NO alert (> not >=)
#   just-above-download  Baseline + 51 (threshold + 1)     → ALERT expected
#   no-baseline          No baseline + 60 of each          → fallback behavior
#   baseline-only        Seed baseline only                → setup step
```

#### Using the CLI (individual events or other detection types)

```bash
cd /Users/rac2/blackpoint/repos/apollo11

# Single event
npm run send_event -- --source ms365 --event <event_type> \
  --package-id 7a00f624-97b0-4f69-aa47-7c6e07ff320a \
  --org-id 2633c608-9ca5-4e45-80d4-f19bc49d9e17 \
  --email rcosta@cloudresponse.dev

# Batch events (login types support --count)
npm run send_event -- --source ms365 --event login_from_unapproved_country \
  --package-id 7a00f624-97b0-4f69-aa47-7c6e07ff320a \
  --org-id 2633c608-9ca5-4e45-80d4-f19bc49d9e17 \
  --email rcosta@cloudresponse.dev \
  --count 10
```

#### Available event types

| Category | Event type | Generator |
|---|---|---|
| **File Activity** | `mass_download` | Sends 60 FileDownloaded events |
| | `unusual_file_download` | via test_unusual_file_activity |
| | `unusual_file_deleted` | via test_unusual_file_activity |
| | `unusual_file_sharing` | via test_unusual_file_activity |
| **Login** | `impossible_travel` | Single event |
| | `login_from_new_device_and_ip` | Supports --count |
| | `login_from_unapproved_country` | Supports --count |
| | `user_locked_out_multiple_failed_logins` | Single event |
| **Admin** | `admin_consented_to_unverified_enterprise_app` | Single event |
| | `admin_consented_to_verified_enterprise_app` | Single event |
| | `user_consented_to_unverified_enterprise_app` | Single event |
| | `user_consented_to_verified_enterprise_app` | Single event |
| | `role_assigned_to_user` | Single event |
| | `role_removed_from_user` | Single event |
| **User lifecycle** | `user_created` | Needs --org-name |
| | `user_deleted` | Needs --org-name |
| **Exchange** | `suspicious_inbox_rule_created` | Sends ~30 variants |
| | `mailbox_access_granted` | Needs --site-org-name |
| | `item_permanently_deleted` | Needs --org-name |
| | `external_email_forwarding_rule_created` | Sends 6 variants |
| **SharePoint** | `share_point_site_created` | Needs --org-name |
| | `share_point_site_deleted` | Needs --org-name |
| | `anonymous_file_link_share_created` | Needs --site-org-name |

### Phase 4: Verification

#### 4a. CCS Consumer Logs

Check that events were processed without errors:

```bash
# Check for processing errors
kubectl logs -n default deployment/cloud-control-events-consumer --tail=100 2>&1 | grep -i "error\|failed\|exception\|DLQ"

# Check for detection firing
kubectl logs -n default deployment/cloud-control-events-consumer --tail=200 2>&1 | grep -i "detection\|alert\|threshold\|baseline"

# Check for specific event processing
kubectl logs -n default deployment/cloud-control-events-consumer --tail=100 2>&1 | grep -i "fileActivity\|mass_download\|unusual"
```

#### 4b. Elasticsearch Verification

Query Elasticsearch for the detection event:

```bash
# Check if ES credentials are available locally
echo $ES_URL $ES_API_KEY

# Query for recent detections from our test user
curl -s -H "Authorization: ApiKey $ES_API_KEY" \
  "$ES_URL/events-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"event.dataset": "CLOUD_RESPONSE_M365"}},
          {"match": {"organization.name": "cloudresponse.dev"}},
          {"range": {"@timestamp": {"gte": "now-1h"}}}
        ]
      }
    },
    "sort": [{"@timestamp": "desc"}],
    "size": 10
  }' | jq '.hits.hits[]._source | {dataset: .event.dataset, action: .event.action, user: .user.email, timestamp: .["@timestamp"]}'
```

For C1-6716 specifically, also check the `baselineType` label:

```bash
# Look for baselineType field in the detection event
curl -s -H "Authorization: ApiKey $ES_API_KEY" \
  "$ES_URL/events-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"event.dataset": "notification.Notification"}},
          {"match": {"organization.name": "cloudresponse.dev"}},
          {"range": {"@timestamp": {"gte": "now-1h"}}}
        ]
      }
    },
    "sort": [{"@timestamp": "desc"}],
    "size": 5
  }' | jq '.'
```

#### 4c. UI Verification (optional)

Use `manual-test-ui-test-compassone` to verify detections appear in CompassOne:

1. Login to staging as BSA
2. Select ABC Bank tenant
3. Navigate to Detections > Cloud Response
4. Search for the detection type
5. Click into the detection detail
6. Verify actor, event time, detection name, and any new fields (e.g., baselineType)

### Phase 5: Results & QA Stamp

After verification, post a QA stamp using the standard format from `qa-stamp`.
Include:

- Which scenario(s) were run
- Event counts sent
- Whether detection fired (or correctly did not fire)
- Consumer log status (errors or clean)
- ES verification results
- Any new fields verified (baselineType, thresholds, etc.)

## Chaining with Bug Bash

After the happy path passes, offer to run `bug-bash-blackpoint` with
backend-specific scenarios:

- **No baseline**: what happens with zero historical data? (sparse baseline test)
- **Boundary values**: exactly at threshold, threshold + 1, threshold - 1
- **Concurrent users**: two users with the same activity pattern
- **Cross-type interaction**: does a download spike affect the sharing threshold?
- **Time boundary**: events spanning two hourly buckets
- **Stale baseline**: very old baseline data (> 14 days)

## Arguments

- `/manual-test-detection-compassone C1-XXXX` - full lifecycle test
- `/manual-test-detection-compassone C1-XXXX --scenario spike-all` - run specific scenario
- `/manual-test-detection-compassone C1-XXXX --verify-only` - skip event injection, just verify

If no ticket is provided, ask: "Which detection ticket should I test?"
