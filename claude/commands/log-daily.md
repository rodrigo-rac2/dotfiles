# Log Daily — Update Daily Work Log

Update today's section in the daily work log for one or more companies. Always checks Jira for what's currently in-flight before writing, so nothing falls through the cracks.

## Company mapping

| Company | File suffix | Ticket prefixes | Atlassian MCP server | Jira base URL |
|---------|-------------|-----------------|----------------------|---------------|
| BP (BPCyber) | `bp` | `TS-`, `C1-`, `AUT-`, `MDR-` | `mcp__Atlassian-BPCyber-Token` | https://bpcyber.atlassian.net |
| ProPark | `propark` | `LPQ-`, `LPA-`, `LP-` | `mcp__Atlassian-Propark-Token` | https://propark.atlassian.net |
| ZenQMS | `zenqms` | `DOR-`, `DTR-`, `QA-`, `C87-` | `mcp__Atlassian-ZenQMS-Token` | https://zenqms.atlassian.net |

User email (all companies): `rcosta@blackpointcyber.com`

If a ticket prefix is ambiguous or company is unclear, ask: "Which company is this for? (bp / propark / zenqms)"

## Arguments

Arguments can be passed in any combination:
- Ticket IDs: `TS-3113 C1-5956`
- Company + description: `propark: Fixed CI flakiness in navigation step`
- Mixed: `LPQ-1191 LPQ-1176` (company auto-detected from prefix)
- No argument: ask the user what to log and for which company

## Steps

### 1. Resolve the log file path

Use today's date (from `currentDate` context or `date +%Y-%m-%d`):
- Compute the **Friday of the current week** (if today IS Friday, use today)
- File: `/Users/rac2/rac2/weekly-log/logs/YYYY/MM/DD-[company].txt`
  - `YYYY`: 4-digit year
  - `MM`: zero-padded month (e.g. `03`)
  - `DD`: zero-padded day of the week's Friday (e.g. `06`)
  - `[company]`: `bp`, `propark`, or `zenqms`

Example: Thursday Mar 5 2026 → Friday is Mar 6 → `logs/2026/03/06-propark.txt`

### 2. Query Jira for in-flight context

Before writing any entries, query Jira for the full picture of what's active. Run in parallel using the company's MCP server:

**a) Open / in-progress tickets assigned to user:**
```
assignee = "rcosta@blackpointcyber.com"
AND status in ("Open", "To Do", "In Progress", "In Testing", "Ready for Testing", "In Review", "Ready for Work")
AND project in ([company projects])
ORDER BY updated DESC
```

**b) Tickets updated today by user:**
```
assignee = "rcosta@blackpointcyber.com"
AND updated >= startOfDay()
AND project in ([company projects])
ORDER BY updated DESC
```

**c) For BP only — tickets in "Ready for Testing" regardless of assignee** (tickets that may have just been handed to QA):
```
status = "Ready for Testing"
AND project in (AUT, C1, TS, MDR)
AND updated >= startOfDay()
ORDER BY updated DESC
```

> If `currentUser()` returns 0 results, use `assignee = "rcosta@blackpointcyber.com"` explicitly.

Read the existing log file. Note all ticket IDs already logged today — skip those in the Jira results to avoid duplication.

Use these results to:
- **Confirm completeness**: if a ticket from query (a) or (b) isn't already in today's log and the user didn't mention it, flag it at the end ("I also see LPQ-XXXX is in-progress — want to log that too?")
- **Provide context** when writing entries: the Jira status and summary inform whether the entry should reflect work-in-progress or completion

### 3. Fetch ticket details (if ticket IDs were given)

For each ticket ID given in the arguments, call `jira_get_issue` on the matching MCP server. Extract:
- **Summary** (ticket title)
- **Description** (for context on the work done)
- **Status** (to frame the entry as in-progress vs. completed)
- **Comments** (last 5, to catch any recent activity context)
- **PR links or key details** from description/comments if present

If the ticket description is sparse, use the summary + status to infer what was done, or ask the user to describe the work.

### 4. Format the log entries

Follow the style of existing entries exactly:

```
Area / Project Name
- TICKET-ID — Concise but technical description: what was built/fixed/tested, root cause if relevant, outcome confirmed, PR numbers, key technical decisions. https://company.atlassian.net/browse/TICKET-ID
- TICKET-ID — Another entry on the same day. https://company.atlassian.net/browse/TICKET-ID
```

Rules:
- Lead with the ticket ID and an em dash: `- TS-3113 — `
- Pack in specific technical details — these are work logs, not summaries. Include: root cause, fix approach, commands run, PRs, what was verified, what passed/failed.
- End with the Jira URL if ticket-based.
- For free-form entries (no ticket), just `- Description of work done.`
- Every entry must be under an `Area / Project` workstream header — this is not optional. Infer it from the ticket area, project name, or nature of the work (e.g. `MDR / Notifications Testing`, `QA / CompassOneQA Code Reviews`, `AUT-3398 / Pipeline Maintenance`, `Linux Distro Automation`).
- Do NOT pad or invent details beyond what is known — be accurate.

### 5. Insert into the log file

1. Read the file.
2. Locate today's weekday section header, e.g. `Thursday, Mar 5`.
3. Find where the next section begins (next weekday header) or end of file.
4. Determine the workstream header for the new entries.
5. **If a matching workstream header already exists in today's section**, append the new bullets directly under it (before the next workstream header or next day).
6. **If no matching workstream header exists**, add it as a new block at the end of today's section, followed by the new bullets.
7. Write the updated file.

Do NOT overwrite or modify other days' content.

### 6. Flag unlisted in-flight tickets

After writing, check the Jira results from step 2 against what was just logged. If any open/in-progress tickets are not covered in today's log, mention them:

> "Also active in Jira: LPQ-XXXX (In Progress) — want to log that too?"

Only flag tickets where there's real activity evidence (updated today, or status recently changed). Don't flag every open ticket.

### 7. Confirm

After writing, output the formatted entries that were added so the user can review them.

## AI assistance tracking

When Claude materially helped with the work being logged — not just logging it, but actually doing it (drafting documents, organizing test scenarios, authoring ticket comments, writing code, etc.) — append an inline `[AI: ...]` note at the end of the relevant bullet, before the Jira URL:

```
[AI: Claude Code (Anthropic) <specific tasks>.]
```

Examples:
- `[AI: Claude Code organized test scenarios, guided execution, and authored QA stamp.]`
- `[AI: Claude Opus drafted full test plan structure and test cases.]`
- `[AI: Claude Code authored the Jira comment and transition.]`

Do NOT add this note when Claude only helped with logging/formatting. Only add it when Claude did substantive work on the actual task.
