# Jira Sync — Sync Daily Log from Jira Activity

Research Jira for all user activity on a specific date, cross-reference linked and related tickets, and append new entries to the work log.

## Arguments

- **Company**: `bp`, `propark`, or `zenqms` (required — ask if not provided)
- **Date**: e.g. `mar5`, `monday`, `yesterday`, `2026-03-05` (optional, defaults to today)

Examples: `/jira-sync bp mar5` · `/jira-sync zenqms yesterday` · `/jira-sync propark monday`

## Company mapping

| Company | File suffix | Projects to search | MCP server prefix | Board ID |
|---------|-------------|-------------------|-------------------|----------|
| BP (BPCyber) | `bp` | AUT, C1, TS, MDR | `mcp__Atlassian-BPCyber-Token` | AUT: 11 |
| ProPark | `propark` | LPQ, LPA, LP | `mcp__Atlassian-Propark-Token` | |
| ZenQMS | `zenqms` | DOR, DTR, QA | `mcp__Atlassian-ZenQMS-Token` | |

## User identity (per company)

| Company | Email |
|---------|-------|
| BP | rcosta@blackpointcyber.com |
| ProPark | rcosta@blackpointcyber.com |
| ZenQMS | rcosta@blackpointcyber.com |

> **Note**: If `currentUser()` JQL returns 0 results, fall back to `assignee = "rcosta@blackpointcyber.com"` explicitly.

---

## Steps

### 1. Resolve company, date, and log file

Parse the arguments to determine company and target date. Convert informal dates (`yesterday`, `monday`, `mar5`) to `YYYY-MM-DD`.

Compute the Friday of the target date's week (if target IS Friday, use it). Log file:
`/Users/rac2/rac2/weekly-log/logs/YYYY/MM/DD-[company].txt`

Read the existing log file. Find the target weekday section (e.g. `Thursday, Mar 5`). Note all ticket IDs already present in that section — skip them in step 6.

---

### 2. Search Jira for user activity on target date

Run the following searches **in parallel** using the company's MCP server. Use `YYYY-MM-DD` as both the start and end date.

**a) Tickets assigned to user, updated on date:**
```
assignee = currentUser() AND updated >= "YYYY-MM-DD" AND updated <= "YYYY-MM-DD" ORDER BY updated DESC
```

**b) All tickets in the company's projects updated on date** (to catch tickets the user commented on or transitioned but doesn't own):
```
project in (AUT, C1, TS, MDR) AND updated >= "YYYY-MM-DD" AND updated <= "YYYY-MM-DD" ORDER BY updated DESC
```
*(adjust project list for company — see mapping above)*

**c) For BP: also search the AUT board (board 11)** using `jira_get_board_issues` with the same JQL as (a).

**d) For BP: search for newly assigned tickets regardless of updated date** — tickets assigned to user that are in `Ready for Testing` status (may have been assigned today without an `updated` timestamp change visible to JQL):
```
assignee = "rcosta@blackpointcyber.com" AND status = "Ready for Testing" AND project in (AUT, C1, TS, MDR)
```
Cross-reference these against the existing log — any that are NOT already logged are candidates.

Collect all ticket keys. Deduplicate across (a), (b), (c), (d). If result set is large (>30), prioritize tickets from (a)/(c) first, then scan (b)/(d) for ones where user activity is evident from summary or context.

---

### 3. Fetch full issue details

For each unique ticket key, call `jira_get_issue` with:
- `fields: "summary,status,description,comment,assignee,updated,created"`
- `expand: "changelog"`
- `comment_limit: 20`

Do this in parallel batches for efficiency.

---

### 4. Filter for user activity on the target date

For each ticket, check the following signals. A ticket qualifies if **any** signal is true:

**Signal A — User commented on target date:**
Filter `comments` where `author.email === user_email` AND the `created` date (strip time) matches target date.
→ Extract the comment body — it's the primary source of truth for the log entry.

**Signal B — User transitioned status on target date:**
Filter `changelog.histories` where `author.email === user_email` AND created date matches target date AND at least one `item.field === "status"`.
→ Note the `fromString → toString` transition.

**Signal C — Assigned to user and updated on target date:**
If `assignee.email === user_email` AND the `updated` date matches target date.
→ Weaker signal — use as a fallback if no comment/transition found.

Discard tickets with no signals from A, B, or C.

---

### 5. Follow referenced tickets in descriptions

For each AUT ticket (summary contains "Manual Test" or similar), the description typically links to an original ticket. Extract referenced ticket keys from:
- URLs like `https://bpcyber.atlassian.net/browse/TS-3113`
- Inline references like `[C1-6117]` or `TS-3113`

Fetch those referenced tickets with `jira_get_issue` to get their summary and description for richer log context.

Also look for referenced tickets in **user's own comments** (e.g. mentions of `C1-5956`, links, PR numbers like `PR #33`).

---

### 6. Determine the primary ticket ID for each log entry

**Prefer the original/parent ticket ID** over the AUT tracking ticket:
- If an AUT "Manual Test - C1-XXXX" ticket links to `C1-XXXX`, log under `C1-XXXX`
- Exception: if the AUT ticket represents original infrastructure/automation work (e.g. building a CLI tool, GHA workflow), log under `AUT-XXXX`

If both the AUT ticket and the original ticket are meaningful and distinct, log them together: `C1-XXXX / AUT-XXXX — ...`

Skip AUT tickets that are purely tracking wrappers for work already logged under C1/TS IDs on this day.

---

### 7. Format log entries

Follow the same format as `log-daily`. Build the description from evidence in this priority order:
1. **User's own comments** on the ticket (most accurate)
2. **Status transition context** ("transitioned from In Progress → Closed", "marked Ready to Deploy")
3. **Linked original ticket** summary + description for context
4. **Ticket summary** as a fallback

Format:
```
Area / Project Header
- TICKET-ID — Specific technical description: what was done, what was verified, root cause if relevant, outcome, PR refs. https://company.atlassian.net/browse/TICKET-ID
```

Rules:
- Lead with ticket ID and em dash: `- C1-6117 — `
- Include technical specifics — commands run, error messages, PR numbers, pass/fail outcomes
- End with the Jira URL
- Group related tickets under an area header (e.g. `Cloud Response / Apollo11`, `MDR / CompassOne`)
- Do NOT invent or pad details beyond what the Jira evidence shows

---

### 8. Insert into the log file

1. Read the current log file
2. Find the target weekday section header (e.g. `Thursday, Mar 5`)
3. Append new entries after any existing content in that section, before the next weekday header
4. If the section is empty, add the area header and bullets
5. Write the file

Do NOT touch other days' sections.

---

### 9. Create missing AUT manual test tickets (BP only)

If a C1/TS ticket is assigned to the user and is in `Ready for Testing` status but has **no corresponding AUT "Manual Test - TICKET-ID" ticket**, create one:

1. **Create** with `jira_create_issue`:
   - `project_key`: `AUT`
   - `issue_type`: `Story`
   - `summary`: `Manual Test - TICKET-ID - [original ticket summary]`
   - `description`: standard AUT template with `*Original ticket:* [TICKET-ID](url)` at the top, and this footer line: `_AI Assisted: This ticket was created and scoped with Claude Code (Anthropic)._`

2. **Assign** with `jira_update_issue`:
   - `fields` must be a **JSON string**: `{"assignee": "rcosta@blackpointcyber.com"}`

3. **Set epic, component, story points** with `jira_update_issue`:
   - `additional_fields` (JSON string): `{"epicKey": "AUT-3192", "customfield_10024": 1}`
   - `components`: `"Automation"`

4. **Add to sprint** with `jira_add_issues_to_sprint`:
   - `sprint_id`: active QA sprint ID (e.g. `3143` for QA Sprint 5)
   - `issue_keys`: plain string `"AUT-XXXX"` — **NOT** a JSON array (that format fails)

> Note: Setting `customfield_10001` (Team) via `additional_fields` fails with an invalid format error — skip it; the team is inferred from the epic.

---

### 10. Confirm

Print all newly added entries so the user can review. If nothing new was found beyond what's already logged, say: "Nothing new to add for [day] — all activity is already logged."

> If Claude materially assisted with any of the work being synced (not just the syncing itself), note it inline on the relevant log entry with `[AI: Claude Code (Anthropic) <specific tasks>.]`

---

### 11. Commit and push

After updating the log file (whether new entries were added or not), run:

```bash
cd /Users/rac2/rac2/weekly-log
git add -A
git commit -m "YYYY-MM-DD - jira-sync [company]"
git push
```

Use the actual target date and company name in the commit message (e.g. `2026-03-06 - jira-sync propark`).
If nothing was added and no files changed, skip the commit.
