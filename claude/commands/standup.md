# Standup — Generate Daily Scrum Update

Generate a daily standup reply in the team's standard format, reading from the weekly work log and enriching with live Jira data.

## Format

```
What have you done in the past day?
[yesterday's work]

Plans for today
[today's planned/in-progress work]

Any blockers?
[blockers or None]
```

## Arguments

- Company name: `bp`, `propark`, or `zenqms` (required — ask if not provided)
- Optional date override: e.g. `propark yesterday=mar4 today=mar5` to override which days to use
- Optional `--all` flag to generate standups for all three companies

## Company mapping

| Company | File suffix | Projects | MCP server prefix | User email |
|---------|-------------|----------|-------------------|------------|
| BP (BPCyber) | `bp` | AUT, C1, TS, MDR | `mcp__Atlassian-BPCyber-Token` | rcosta@blackpointcyber.com |
| ProPark | `propark` | LPQ, LPA, LP | `mcp__Atlassian-Propark-Token` | rcosta@blackpointcyber.com |
| ZenQMS | `zenqms` | DOR, DTR, QA, C87 | `mcp__Atlassian-ZenQMS-Token` | rcosta@blackpointcyber.com |

## Steps

### 1. Determine the company and log file

Map company argument to log file suffix: `bp`, `propark`, or `zenqms`.

Resolve the log file path (same as `log-daily`):
- Compute the Friday of the current week from today's date
- File: `/Users/rac2/rac2/weekly-log/logs/YYYY/MM/DD-[company].txt`

### 2. Determine "yesterday" and "today"

Use today's date from `currentDate` context:
- **Yesterday** = the previous workday (skip weekends):
  - If today is Monday → yesterday is Friday
  - Otherwise → the calendar day before today
- **Today** = today's weekday

> **Override rule**: If the user specifies `yesterday=` or `today=` in the arguments, use those instead.

### 3. Read and extract log entries

Read the log file and extract the bullet points under the yesterday and today weekday sections.

- Find the section header matching yesterday's weekday and date (e.g. `Wednesday, Mar 4`)
- Collect all bullet points under it (stop at the next weekday header)
- Find the section for today and do the same

### 4. Query Jira for live context (run in parallel)

Using the company's MCP server, run the following searches in parallel:

**a) Tickets assigned to user, updated yesterday** (confirms and fills gaps in "yesterday" section):
```
assignee = "rcosta@blackpointcyber.com"
AND updated >= "YYYY-MM-DD (yesterday)"
AND updated <= "YYYY-MM-DD (yesterday)"
AND project in ([company projects])
ORDER BY updated DESC
```

**b) Open / in-progress tickets assigned to user** (drives "Plans for today"):
```
assignee = "rcosta@blackpointcyber.com"
AND status in ("Open", "To Do", "In Progress", "In Testing", "Ready for Testing", "Ready for Work", "In Review")
AND project in ([company projects])
ORDER BY updated DESC
```

**c) Tickets transitioned by user yesterday** (catches status changes not always visible in assignee search):
```
assignee = "rcosta@blackpointcyber.com"
AND status changed AFTER "YYYY-MM-DD (yesterday 00:00)"
AND status changed BEFORE "YYYY-MM-DD (today 00:00)"
AND project in ([company projects])
```

> If `currentUser()` returns 0 results, substitute `assignee = "rcosta@blackpointcyber.com"` explicitly.

Deduplicate across all three searches. Use these results to:
- **Enrich yesterday**: if the log is sparse or empty for yesterday, pull from queries (a) and (c) to fill in what was worked
- **Drive "Plans for today"**: if today's log section is empty, use query (b) open items as the primary source for plans — these are the real in-flight tickets
- **Detect blockers**: tickets stuck in the same status for 3+ days, or notes like "waiting on", "blocked" in comments

### 5. Check previous standups for context

Read the 2 most recent standup files for this company from `standups/YYYY/MM/DD-[company].md` (sorted by date descending).

Use these to:
- Avoid repeating the same "plans for today" two days in a row if there's no log or Jira activity supporting it
- Identify tickets that have been "in plans" for multiple days and escalate them — if a ticket has been in plans 2+ consecutive days with no log activity, note it as a likely blocker or stalled item

### 6. Format the standup

Condense all evidence (log + Jira) into standup-appropriate language:

- **What have you done in the past day?** → Summarize yesterday's log bullets, enriched by Jira transitions if the log is sparse. Reference ticket IDs and PR numbers. 1–3 sentences or a short bullet list. If there are items from multiple workstreams (e.g. code reviews, manual testing, CI fixes), group them under plain-text workstream labels.
- **Plans for today** → If today's log is populated, use it. If empty, use open/in-progress tickets from Jira query (b) as primary source — phrase as forward-looking intent ("Continue X", "Implement Y"). List 2–4 most actionable items. Group by workstream if there are multiple areas.
- **Any blockers?** → Infer from log entries (mentions of "blocked", "waiting on", "failed") and from tickets stuck in the same status with no recent updates. Default to `None`.

Keep it short — standup answers are meant to be quick reads. Ticket IDs and PR numbers are good to include; deep technical detail is not. Workstream labels are plain text, no bullet. Always put a blank line after the section header ("What have you done in the past day?", "Plans for today") and a blank line between each workstream group — Teams collapses consecutive lines and this spacing prevents the section header and first workstream label from merging into one line.

If a log entry contains an `[AI: ...]` marker, preserve it inline on that bullet — e.g. `(AI: Claude Code organized test scenarios and authored QA stamp.)`. This is how management tracks AI usage on actual work, not on standup generation.

### 7. Write the standup file

Save the standup to:
- Path: `/Users/rac2/rac2/weekly-log/standups/YYYY/MM/DD-[company].md`
  - `YYYY/MM` = year and month of today's date
  - `DD` = today's day (zero-padded)
  - Create the directory if it does not exist
- Format: Plain text only — no markdown headings or `##`. Use the section labels exactly as they appear in the console output. The file is meant to be copy-pasted into Teams, so markdown formatting must not be used.

### 8. Output

Print the formatted standup to the console and confirm the file path written.

## Example output

The output must use plain text labels — no `##` or `**bold**` markdown. Section headers are plain words followed by a **blank line**, then the workstream label. A blank line separates each workstream group. This blank line is required so Teams does not collapse the section header and the first workstream label onto the same visual line. Bullets use `-`.

```
What have you done in the past day?

E2E test automation
- LPQ-1212–LPQ-1227 / PR #695: Implemented 16-test cross-env E2E suite — LPA creates a promo code, Proparcs validates it through Stripe checkout and receipt email. 16/16 passing.

Plans for today

E2E test automation
- LPQ-1550: Fix SMS OTP auth failure in cross-env Proparcs test — applying Firebase Admin route interception pattern from LPQ-1544.
- LPQ-1489: Follow up on PR #364 review feedback.

Any blockers?
None

---
Saved to standups/2026/04/03-propark.md
```
