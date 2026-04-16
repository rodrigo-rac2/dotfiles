# Standup End of Day — Generate Daily Status Report

Generate an end-of-day status report in the team's format (Yulia-style), summarizing today's work with inline status per item and plans for tomorrow.

## Format

```
Today's Status (M/D/YYYY):

What I worked on:
[item] - [status]
[item] - [status]

New bugs:
[bug description or "None"]

Plans for tomorrow:
[item]
[item]

Any Blockers:
[blockers or No]
```

## Arguments

- Company name: `bp`, `propark`, or `zenqms` (required — ask if not provided)
- Optional date override: e.g. `bp today=apr14` to override the target date

## Company mapping

| Company | File suffix | Projects | MCP server prefix | User email |
|---------|-------------|----------|-------------------|------------|
| BP (BPCyber) | `bp` | AUT, C1, TS, MDR | `mcp__Atlassian-BPCyber-Token` | rcosta@blackpointcyber.com |
| ProPark | `propark` | LPQ, LPA, LP | `mcp__Atlassian-Propark-Token` | rcosta@blackpointcyber.com |
| ZenQMS | `zenqms` | DOR, DTR, QA, C87 | `mcp__Atlassian-ZenQMS-Token` | rcosta@blackpointcyber.com |

## Steps

### 1. Resolve company, date, and log file

Use today's date from `currentDate` context (or the override). Format the header date as `M/D/YYYY` (no zero-padding — e.g. `4/14/2026`).

Compute the Friday of the current week. Log file:
`/Users/rac2/rac2/weekly-log/logs/YYYY/MM/DD-[company].txt`

### 2. Read today's log section

Read the log file. Find today's weekday header (e.g. `Tuesday, Apr 14`). Extract all bullet points under it.

### 3. Query Jira for today's activity and status

Run in parallel using the company's MCP server:

**a) Tickets assigned to user, updated today:**
```
assignee = "rcosta@blackpointcyber.com"
AND updated >= startOfDay()
AND project in ([company projects])
ORDER BY updated DESC
```

**b) Open / in-progress tickets assigned to user** (for "Plans for tomorrow"):
```
assignee = "rcosta@blackpointcyber.com"
AND status in ("Open", "To Do", "In Progress", "In Testing", "Ready for Testing", "Ready for Work", "In Review")
AND project in ([company projects])
ORDER BY updated DESC
```

For each ticket appearing in today's log or in query (a), fetch its current status from Jira to use in the inline status label.

### 4. Map ticket status to inline status labels

Convert Jira status to human-readable inline status for each item:

| Jira status | Label |
|---|---|
| Closed / Done / Resolved | `Closed` |
| In Code Review | `in PR review` |
| Ready for Testing | `ready for testing` |
| In Testing | `in testing` |
| In Progress | `in progress` |
| Ready for Work / To Do / Open | `not started` |
| Deployed to staging, pending prod | `passed staging, pending deployment to prod` |

Use context from log entries and Jira comments to enrich the label — e.g. "partially passed, one additional fix pending deployment" when the log says a partial QA stamp was posted.

### 5. Build "What I worked on" items

For each bullet in today's log section, produce one line. Format rules:

- **Manual test items** (log entry contains "manual test", "Manual Test", "AUT-XXXX" tracking ticket for a C1/TS ticket): prefix with `Manual test: [TICKET-ID] -`
  - Example: `Manual test: [C1-6318] - Global Notifications 4 new triggers - Closed`
- **Code reviews**: prefix with `Code review:`
  - Example: `Code review: PR #583 (AutoTask PSA tenant mapping) - REQUEST_CHANGES`
- **Pipeline / CI / infrastructure**: no prefix, just describe concisely
  - Example: `AUT-3420: Debian 13 GitHub Actions runner expansion (2 new VMs) - Closed`
- **All other items**: `TICKET-ID: concise description - status`

Keep each line short — one line per logical work item. If the log bullet covers multiple sub-items (e.g. "completed X, Y, Z"), split into separate lines only if they have different statuses. Otherwise keep as one line with a combined summary.

If a log entry has an `[AI: ...]` marker, preserve it inline: `(AI: Claude Code drove deployment end-to-end.)`.

### 6. Build "New bugs" section

Scan today's log and Jira results for:
- Tickets with issue type Bug/Defect created or transitioned today
- Log entries mentioning "new bug", "filed a bug", "opened a defect"

If none found, output `None`.

Format: `[TICKET-ID] - Brief bug description` or just a plain description if no ticket yet.

### 7. Build "Plans for tomorrow" section

Use query (b) open/in-progress items. Select 3–5 most actionable items. Prioritize:
1. Tickets currently "In Testing" or "Ready for Testing" (active testing work)
2. Tickets with recent activity (updated today or yesterday)
3. Tickets in "In Progress"

Phrase as action-oriented lines:
- `Test [TICKET-ID] - [summary]`
- `Continue [TICKET-ID] - [summary]`
- `Code review: [PR description]`
- `[Free-form plan if no ticket]`

### 8. Build "Any Blockers" section

Infer from log entries ("blocked", "waiting on", "failed", "unconfirmed root cause") and tickets stuck in the same status for 3+ days. Default to `No`.

### 9. Format and write the output

**Formatting rules (same as /standup-startofday):**
- Plain text only — no markdown, no bold, no bullet symbols except `-` for list items
- Blank line after each section header
- Blank line between logical groups within "What I worked on" if there are multiple workstreams
- The file is meant to be copy-pasted into Teams

Save to:
- Path: `/Users/rac2/rac2/weekly-log/standups/YYYY/MM/DD-[company]-endofday.md`

Commit and push:
```bash
cd /Users/rac2/rac2/weekly-log
git add -A
git commit -m "YYYY-MM-DD - standup-endofday [company]"
git push
```

### 10. Output

Print the formatted report to the console and confirm the file path.

## Example output

```
Today's Status (4/14/2026):

What I worked on:

MDR / Notifications Testing
- Manual test: [C1-6318] - Global Notifications 4 new triggers (staging + prod) - Closed (AI: Claude Code performed browser automation and authored QA stamp.)
- Manual test: [C1-6317] - New detections opt-in/suppression for onboarding - received for testing, in queue
- Manual test: [C1-6305] - Mass download detection threshold push - in progress

GitHub Actions / CI
- AUT-3420: Debian 13 GitHub Actions runner expansion — 2 new VMs, ARM secret rotation, pip3 fix, state drift resolved - Closed (AI: Claude Code drove deployment end-to-end.)

Code reviews
- Code review: PR #583 (AutoTask PSA tenant mapping round 3) - REQUEST_CHANGES
- Code review: PR #585 (AUT-3401 vendor API rounds 2 and 3) - APPROVED
- Code review: PR #588 (AUT-3430 Cisco FTD events) - REQUEST_CHANGES

New bugs:
None

Plans for tomorrow:

- Test C1-6317 - new detections opt-in/suppression for onboarding (Prod SOC APG with feature flag)
- Test C1-6425 - CCS VPN profile table locking fix (PR #1616 stress test)
- Test C1-6314 - SNAP UI for 4 new MDR detections
- Continue C1-6305/AUT-3425 - mass download detection threshold testing

Any Blockers:
No

---
Saved to standups/2026/04/14-bp-endofday.md
```
