---
name: bug-bash-blackpoint
description:
  Exploratory bug bash for Blackpoint CompassOne. Given a Jira ticket, analyzes
  the feature under test, confirms the happy path, then systematically explores
  alternative paths to find bugs. Uses playwright-cli for browser automation.
  Calculates explorable scenarios with effort estimates so the user can choose
  a time budget. Produces a structured findings report with proposed bugs.
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
  - mcp__Atlassian-BPCyber-Token__jira_create_issue
  - mcp__Atlassian-BPCyber-Token__jira_search
---

# Bug Bash - Blackpoint CompassOne

Systematic exploratory testing that goes beyond happy-path confirmation.
Given a Jira ticket, this skill thinks like a QA engineer looking to break
things, not just confirm they work.

## When This Skill Triggers

- Directly: `/bug-bash-blackpoint C1-XXXX`
- Chained: from `manual-test-ui-test-compassone` after happy path passes

## Workflow

### Phase 1: Reconnaissance (always runs)

1. **Fetch the ticket** from Jira (`jira_get_issue` with `fields: "*all"`, `comment_limit: 10`)
2. **Analyze the feature** by reading:
   - Summary and description (what was built)
   - Acceptance criteria (what devs tested)
   - Comments (deployment notes, known issues, test instructions)
   - Related tickets / epic context
3. **Identify the feature surface area**:
   - Which UI pages are affected?
   - Which API endpoints are involved?
   - Which user roles interact with this feature?
   - What data flows through the feature?
   - What are the state transitions?

### Phase 2: Scenario Generation

Generate alternative test scenarios across these categories. For each scenario,
estimate effort in minutes.

#### Category Checklist

| Category | What to look for | Typical effort |
|----------|-----------------|----------------|
| **Boundary values** | Empty inputs, max length, special chars (`<script>`, unicode, emoji), zero/negative numbers, very long strings | 2-5 min each |
| **RBAC & permissions** | Test the same action as different roles (BSA, BA, BU, AA, AU, CA, CU). Can a lower role access/modify what they shouldn't? | 3-5 min per role |
| **State transitions** | Toggle on/off/on. Enable then disable. Connect then disconnect. What happens mid-transition? | 3-5 min each |
| **Error handling** | What happens with invalid data? Missing required fields? Network timeout? Submitting a form twice? | 2-4 min each |
| **Data integrity** | Does data persist after page refresh? After logout/login? Is there cross-tenant data leakage? | 3-5 min each |
| **Concurrency** | Rapid double-clicks on submit buttons. Opening the same form in two tabs. | 2-3 min each |
| **Edge cases** | Zero items in a list. Pagination at boundary (exactly N items). Last item deletion. First-time empty state. | 2-4 min each |
| **Negative tests** | Actions that SHOULD fail. Unauthorized access attempts. Invalid API payloads reflected in UI. | 2-5 min each |
| **Regression** | Adjacent features that share UI components or data. Did the change break anything nearby? | 5-10 min each |
| **Visual/UX** | Truncated text, broken layouts at different viewport sizes, missing loading states, unhelpful error messages | 2-3 min each |
| **Console & network** | JS errors in browser console. Failed network requests. Unexpected 4xx/5xx responses. | 1-2 min (passive) |

#### How to Generate Scenarios

Think adversarially. For each AC item, ask:
- "What if the opposite happens?"
- "What if this is done by a different role?"
- "What if the precondition isn't met?"
- "What if this is done twice?"
- "What if the data is malformed?"
- "What if a related feature changed?"

Produce a numbered list of scenarios with:
```
[ID] Category — Scenario description (estimated: X min)
```

Example:
```
[1] RBAC — Verify Customer User cannot see/toggle the new detection settings (est: 4 min)
[2] Boundary — Toggle all 4 detections on/off rapidly and verify final state is consistent (est: 3 min)
[3] State — Enable detection, refresh page, confirm toggle state persists (est: 2 min)
[4] Regression — Check that existing detection toggles still work after the change (est: 5 min)
[5] Edge — New connection with zero users: do detection settings still appear? (est: 4 min)
[6] Console — Monitor browser console for JS errors during toggle interactions (est: 2 min)
```

### Phase 3: Time Budget & Selection

Present the scenario list to the user with total estimated time.

Ask: **"I found N explorable scenarios (total est: ~X min). How much time do we have for bug bashing?"**

Options:
- **Quick (10-15 min)**: pick the highest-risk scenarios
- **Standard (20-30 min)**: cover all categories at least once
- **Thorough (45-60 min)**: explore everything including edge cases
- **Custom**: user specifies exact minutes

Selection priority (when time is limited):
1. RBAC violations (security impact)
2. Data integrity issues (data loss risk)
3. Console/network errors (passive, free to check)
4. State transitions (functional correctness)
5. Boundary values (input validation)
6. Edge cases & regression
7. Visual/UX

### Phase 4: Execution

For each selected scenario:

1. **Open browser** with `playwright-cli open <URL>`
2. **Login** as the appropriate role (follow manual-test-ui-test-compassone login flow)
3. **Navigate** to the feature under test
4. **Execute** the scenario step by step
5. **Capture evidence**:
   - `playwright-cli screenshot` at key moments
   - `playwright-cli console` to check for JS errors
   - `playwright-cli network` to check for failed requests
   - Note exact steps taken and what was observed
6. **Classify the result**:
   - **PASS**: behavior is correct
   - **BUG**: unexpected behavior found
   - **QUESTION**: behavior is ambiguous, needs clarification
   - **FLAKY**: inconsistent results, needs investigation

### Phase 5: Findings Report

After all scenarios are executed, produce a structured report:

```
## Bug Bash Report — <TICKET-KEY>

**Feature:** <one-line description>
**Environment:** staging / production
**Date:** <date>
**Duration:** <actual time spent>
**Scenarios explored:** X of Y

### Summary
- X scenarios passed
- X bugs found
- X questions raised

### Bugs Found

#### BUG-1: <title>
- **Severity:** Critical / High / Medium / Low
- **Category:** <from checklist>
- **Steps to reproduce:**
  1. ...
  2. ...
- **Expected:** ...
- **Actual:** ...
- **Screenshot:** <filename>
- **Console errors:** <if any>

#### BUG-2: ...

### Passed Scenarios
- [1] RBAC — Customer User correctly blocked from detection settings
- [3] State — Toggle state persists after refresh
- ...

### Questions / Ambiguities
- [5] Is it intentional that new connections show all detections disabled, including non-new ones?

### Not Explored (out of time budget)
- [7] Visual — viewport resize testing
- ...
```

### Phase 6: Bug Creation (optional)

For each bug found, offer to create a Jira ticket:

- **Project:** C1 (or the source ticket's project)
- **Type:** Bug
- **Summary:** `[BUG] <description> — found during bug bash of <SOURCE-KEY>`
- **Description:** full repro steps, expected vs actual, screenshots
- **Priority:** based on severity assessment
- **Labels:** `bug-bash`
- **Link:** relates to the source ticket

Ask the user before creating: "Found X bugs. Want me to create Jira tickets for them?"

## Backend vs UI Detection

When analyzing the ticket, determine the test surface:

- **UI feature** (toggles, settings pages, display changes) → use playwright-cli
- **Backend detection logic** (thresholds, baselines, event processing) → use apollo11 + kubectl
- **Both** (new detection type that fires AND shows in UI) → combine both approaches

### Backend Bug Bash Scenarios

For detection logic tickets, generate scenarios from these categories:

| Category | What to look for | Tools |
|---|---|---|
| **Threshold boundary** | Exactly at threshold, threshold +/- 1, zero events | apollo11 test runner |
| **No baseline** | User with no historical data, what's the fallback? | Redis clear + apollo11 |
| **Stale baseline** | Very old data (> 14 days), does it age out correctly? | Redis inspection |
| **Cross-type interference** | Does a download spike affect sharing thresholds? | apollo11 multi-scenario |
| **Time boundary** | Events spanning two hourly buckets | apollo11 with custom timestamps |
| **Concurrent users** | Two users with identical patterns | apollo11 with different --email |
| **Consumer resilience** | Events during consumer restart, DLQ routing | kubectl logs + apollo11 |
| **Kafka ordering** | Out-of-order events, does detection still fire? | apollo11 batch with shuffled times |

### Backend Execution

Use the `manual-test-detection-compassone` skill for the actual test lifecycle:

```bash
# apollo11 repo
cd /Users/rac2/blackpoint/repos/apollo11

# Available test scenarios
npm run test_unusual_file_activity

# Run a scenario
NODE_ENV=staging npm run test_unusual_file_activity -- --scenario <name>

# Send individual events
npm run send_event -- --source ms365 --event <type> \
  --package-id 7a00f624-97b0-4f69-aa47-7c6e07ff320a \
  --org-id 2633c608-9ca5-4e45-80d4-f19bc49d9e17 \
  --email rcosta@cloudresponse.dev

# Check consumer logs
kubectl logs -n default deployment/cloud-control-events-consumer --tail=100 2>&1 | grep -iE "error|detection|threshold|baseline"

# Verify in Elasticsearch
curl -s -H "Authorization: ApiKey $ES_API_KEY" \
  "$ES_URL/events-*/_search" -H "Content-Type: application/json" \
  -d '{"query":{"bool":{"must":[{"match":{"event.dataset":"notification.Notification"}},{"match":{"organization.name":"cloudresponse.dev"}},{"range":{"@timestamp":{"gte":"now-30m"}}}]}},"size":5}' | jq '.'
```

## Using playwright-cli

This skill uses `playwright-cli` (not Playwright MCP) for UI-focused automation.

Key commands:
```bash
playwright-cli open <url>          # Open browser
playwright-cli snapshot            # Capture DOM snapshot (get element refs)
playwright-cli click <ref>         # Click element by ref
playwright-cli fill <ref> <text>   # Fill input
playwright-cli type <text>         # Type on keyboard
playwright-cli screenshot          # Take screenshot
playwright-cli console             # Check JS console errors
playwright-cli network             # Check network requests
playwright-cli eval <js> [ref]     # Evaluate JavaScript
playwright-cli close               # Close browser
```

Read snapshot YAML files to find element refs. Use `Grep` to search snapshots
for specific text or elements.

## Login Flow Reference

Use the same login flow as `manual-test-ui-test-compassone`:

- BSA credentials: `config/.env` + `config/.env.staging` (or `.env.prod`)
- BSA email: `qaautomatedusersa@blackpointcyber.com` (needs `?use-password-internal=true`)
- Other roles use `+suffix` aliases (no SSO bypass needed)
- TOTP generation: `otpauth` library in CompassOneQA repo at `/Users/rac2/blackpoint/repos/CompassOneQA`

## Arguments

- `/bug-bash-blackpoint C1-XXXX` — run standalone bug bash on a ticket
- `/bug-bash-blackpoint C1-XXXX --quick` — quick 10-15 min session
- `/bug-bash-blackpoint C1-XXXX --thorough` — full 45-60 min session

If no ticket is provided, ask: "Which ticket should I bug bash?"

## Rules

- Always start with reconnaissance. Never jump into testing without understanding the feature.
- Think like an adversary, not a validator. Your job is to find what's broken.
- Capture evidence for everything. A bug without a screenshot is a rumor.
- Check the browser console on EVERY page load. Free bugs live there.
- Test with at least 2 different roles when RBAC is relevant.
- Never modify production data without explicit user confirmation.
- Report findings honestly. If you found nothing, say so. If time ran out, say what was skipped.
- Propose bugs with specific, reproducible steps. Vague findings waste developer time.
