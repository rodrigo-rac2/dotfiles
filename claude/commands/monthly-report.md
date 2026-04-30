# Monthly Report — Generate Monthly Status Update

Read all log files for a company for a given month, enrich with live Jira data, and generate a monthly status update covering completed epics/automation work, in-progress items, and anything pushed to next month.

## Arguments

- **Company**: `bp`, `propark`, or `zenqms` (required — ask if not provided)
- **Month**: e.g. `april`, `apr`, `2026-04` (optional, defaults to current month)

Examples: `/monthly-report bp` · `/monthly-report bp april` · `/monthly-report propark 2026-03`

---

## Output format

No markdown headers — plain text section labels only (no `#`, `##`, `###`). This avoids font size differences when pasted into external tools.

```
[Month] Monthly Update — Rodrigo Costa

Completed

- **Epic or workstream name (ticket)** — one-sentence outcome. What shipped, what was validated, what was automated.

In Progress

- **Epic or workstream name (ticket)** — current state and what's left.

Pushed to Next Month

- **Epic or workstream name** — what was deferred and why (one short reason).
```

### Content rules

- **Epics and automation work only** — no story-level detail. Group related stories under their parent epic or workstream.
- **Completed**: things that are fully done — QA passed, merged, closed, shipped to prod. One bullet per epic/theme.
- **In Progress**: things actively underway but not done. State where things stand, not what was done.
- **Pushed to Next Month**: items that were scoped or started but won't finish this month. Always include the reason (blocked, deprioritized, waiting on someone).
- Bold the epic/workstream label; keep ticket refs in parentheses if helpful.
- Write at a level a VP could read — no function names, config keys, or implementation steps.
- No em dashes in prose. No semicolons in prose. Use periods or commas instead.

---

## Company → Jira mapping

| Company | File suffix | Projects to search | MCP server prefix |
|---------|-------------|-------------------|-------------------|
| BP (BPCyber) | `bp` | AUT, C1, TS, MDR | `mcp__Atlassian-BPCyber-Token` |
| ProPark | `propark` | LPQ, LPA, LP | `mcp__Atlassian-Propark-Token` |
| ZenQMS | `zenqms` | DOR, DTR, QA, C87 | `mcp__Atlassian-ZenQMS-Token` |

User email (all companies): `rcosta@blackpointcyber.com`

---

## Steps

### 1. Resolve company, month, and file paths

Parse arguments to determine company and target month. Default to the current month.

- **Log files**: `/Users/rac2/rac2/weekly-log/logs/YYYY/MM/*-[company].txt` — read all files for the month
- **Report file**: `/Users/rac2/rac2/weekly-log/reports/YYYY/MM/[company]-monthly-update.md`

Ensure the reports directory exists (create if needed).

---

### 2. Read all log files for the month

Glob `logs/YYYY/MM/*-[company].txt` and read every file found. Extract all bullet points across all weeks. Group entries by epic, workstream, or area (same tickets, same system, related work).

If no log files exist for the month, stop and tell the user.

---

### 3. Query Jira for monthly activity

Run the following in **parallel** using the company's MCP server.

**a) Completed this month** — tickets closed or resolved:
```
assignee = "rcosta@blackpointcyber.com"
AND status changed to (Closed, Done, Resolved, "Ready for Deployment", "Pending Release")
AFTER "YYYY-MM-01"
BEFORE "YYYY-MM-[last day + 1]"
AND project in ([company projects])
ORDER BY updated DESC
```

**b) Still open / in-flight**:
```
assignee = "rcosta@blackpointcyber.com"
AND status in ("Open", "To Do", "In Progress", "In Testing", "Ready for Testing", "Ready for Work", "Ready for Deployment")
AND project in ([company projects])
ORDER BY updated DESC
```

Use `limit: 50` for (a), `limit: 30` for (b). Deduplicate.

Use the Jira results to:
- Confirm what's truly done vs. still open
- Catch items closed in Jira that are lightly logged
- Identify "In Progress" items that didn't finish
- Detect items that were started but never moved (candidates for "Pushed to Next Month")

---

### 4. Check for an existing report

Read the report file if it exists.

- If it has real content, ask the user whether to overwrite or append.
- If empty or missing, proceed.

---

### 5. Generate the report

Synthesize log entries and Jira results into the three plain-text sections.

**Completed**: One bullet per epic or automation theme. Lead with the outcome. Collapse all stories/tickets under their epic into a single bullet. Mark as Completed only if Jira status confirms it (Closed, Done, Pending Release, or equivalent). If a ticket is still open in Jira, it does not belong here.

**In Progress**: One bullet per active epic or workstream. Describe current state, not what was done. Use Jira query (b) as the source of truth — if it's open in Jira, it belongs here unless it's clearly deferred.

**Pushed to Next Month**: Items scoped or started this month but not finishing. Look for: items open in Jira with no progress, items the log mentions as blocked or deferred, items where work started late in the month. Always include a brief reason.

**Brevity rules**:
- No file names, function names, config keys, or implementation steps
- Ticket IDs are OK in parentheses for traceability
- One bullet per epic — not per story
- Skip items that are too small to mention at a VP level

---

### 6. Write the report file

Write to `reports/YYYY/MM/[company]-monthly-update.md`.

---

### 7. Commit and push

```bash
cd /Users/rac2/rac2/weekly-log
git add -A
git commit -m "YYYY-MM - monthly-report [company]"
git push
```

Use the actual year-month and company in the commit message.

---

### 8. Confirm

Print the full report so the user can review it.
