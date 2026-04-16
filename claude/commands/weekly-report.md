# Weekly Report — Generate Weekly Status Report

Read the week's work log for a company, enrich it with live Jira data (completed this week + open items), and generate a weekly status update — what got done, what's coming, any blockers. Written to sound like a person wrote it, not a report template.

## Arguments

- **Company**: `bp`, `propark`, or `zenqms` (required — ask if not provided)
- **Date**: e.g. `mar7`, `2026-03-06` (optional, defaults to current week)

Examples: `/weekly-report bp` · `/weekly-report propark mar7` · `/weekly-report zenqms 2026-03-28`

---

## Report format

```
What got done this week

Workstream label
- [outcome — what was completed or shipped]

Another workstream label
- [outcome]

Coming up next week

Workstream label
- [planned work]

Blockers
[bullets — anything waiting on someone else, stalled, or at risk — or "None"]
```

### Section guidance

**What got done this week**: Group bullets under plain-text workstream labels (e.g. "MDR manual testing", "Code reviews", "Test automation"). Lead with the outcome, not the process. Skip ticket IDs — write it the way you'd tell your manager in a hallway. Include ticket refs only if they add clarity. 4–8 bullets total across all workstreams.

**Coming up next week**: Group bullets under plain-text workstream labels. Based on open/in-progress items from Jira (To Do, In Progress, Ready for Testing, etc.) and natural next steps from completed work. 3–5 bullets.

**Blockers**: Anything stalled, waiting on another team, needs a decision, or was escalated and hasn't resolved. If nothing qualifies, write "None." No workstream grouping needed here.

### Tone rules

This is a weekly check-in, not a status report. Write it the way a person would type it to their manager in Slack or Teams:
- First person ("Wrapped up…", "Still working through…", "Waiting on…")
- Conversational but professional — no corporate filler ("leveraged", "facilitated", "synergized")
- Specific and concrete — name the feature, the customer, the outcome
- Short sentences. Not every bullet needs to be perfectly parallel
- If something was annoying or surprising, it's OK for that to show ("Turns out the E2E test for this isn't really feasible in staging — went with unit test coverage instead")

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

### 1. Resolve company, date, and file paths

Parse the arguments to determine company and target date. Convert informal dates to `YYYY-MM-DD`. Default to today.

Compute the Friday of the target date's week (if target IS Friday, use it). Also compute the Monday of that week.

- **Log file**: `/Users/rac2/rac2/weekly-log/logs/YYYY/MM/DD-[company].txt`
- **Report file**: `/Users/rac2/rac2/weekly-log/reports/YYYY/MM/DD-[company].txt`

Ensure the reports directory exists (create if needed).

---

### 2. Read the last 2 prior reports for calibration

Find the two most recent existing report files for this company under `reports/` (the ones dated before the current week). Read them.

Use them as your **tone and length reference only** — how direct and personal they sound, how many bullets per section. Do NOT copy their structure or section names. The format is always the three-section format defined above (What got done / Coming up next week / Blockers), regardless of what prior reports look like.

If prior reports are short and punchy, match that energy. Do not write more than they do.

If no prior reports exist, default to 4–6 bullets per section, conversational tone.

---

### 3. Read the log file

Read the full log file. It contains Mon–Fri sections. Extract all bullet points from all five days. Group by work stream (same area, same project, or related tickets).

If the log file does not exist or is empty, stop and tell the user there is no log to generate a report from.

---

### 4. Query Jira for weekly activity

Run the following three searches **in parallel** using the company's MCP server.

**a) Completed this week** — tickets closed or resolved during Mon–Fri:
```
assignee = "rcosta@blackpointcyber.com"
AND status changed to (Closed, Done, Resolved, "Ready for Deployment")
AFTER "YYYY-MM-DD (Monday)" BEFORE "YYYY-MM-DD (Friday + 1 day)"
AND project in ([company projects])
ORDER BY updated DESC
```

**b) Open / in-flight items** — tickets currently assigned and active:
```
assignee = "rcosta@blackpointcyber.com"
AND status in ("Open", "To Do", "In Progress", "In Testing", "Ready for Testing", "Ready for Work", "Ready for Deployment")
AND project in ([company projects])
ORDER BY updated DESC
```

**c) In-progress items the user worked on** (to catch tickets not owned but touched this week):
```
project in ([company projects])
AND updated >= "YYYY-MM-DD (Monday)"
AND updated <= "YYYY-MM-DD (Friday)"
AND status in ("In Progress", "In Testing")
ORDER BY updated DESC
```
Scan result (c) for tickets where the assignee email matches `rcosta@blackpointcyber.com` — keep those.

Use `limit: 30` for (a) and (b), `limit: 50` for (c). Deduplicate across all three.

> **Note**: If `currentUser()` JQL returns 0 results, substitute `assignee = "rcosta@blackpointcyber.com"` explicitly.

#### What to do with the results

- **Query (a) results** → enrich the **"What got done this week"** section. Cross-reference against the log: if a completed ticket isn't in the log at all, include it in the report anyway (the Jira title is enough context).
- **Query (b) results** → drive the **"Coming up next week"** section. These are the real open items heading into the next week. Prefer this over inferring from the log alone.
- **Query (c) results** → supplement (a) — may surface in-progress items that moved forward but didn't close.

For each Jira ticket found in (a) or (b) that is NOT already covered by the log, note its summary and status for use in the report. You do NOT need to fetch full issue detail — summaries are sufficient for report generation.

---

### 5. Check for an existing report

Read the report file if it exists.

- If it already has real content (beyond empty section headers), ask the user whether to overwrite or append.
- If empty or missing, proceed.

---

### 6. Generate the report

Synthesize **both** the log and the Jira query results into the three sections.

**What got done**: Combine log entries + query (a)/(c) completions. Focus on outcomes. Collapse multi-day work on the same ticket into one bullet. If a ticket was closed in Jira this week, it belongs here even if thinly logged. Don't list steps — list outcomes. If a log entry contains an `[AI: ...]` marker, carry it inline on the bullet.

**Coming up next week**: Use query (b) as your primary source — these are the real open items in Jira. Supplement with natural next steps from completed work. Make it forward-looking and specific. Phrase as intent ("Picking up…", "Continuing…", "Starting…").

**Blockers**: Look for signals in the log (escalations, waiting on other people, tests that couldn't be completed) AND in Jira (items stuck in the same status for the whole week, items assigned to others that are blocking the user's work). Be honest. If none, say so.

**Brevity rules**:
- No file names, function names, config keys, or implementation detail
- No ticket IDs in "Coming up" or "Blockers" unless they're the best way to identify something
- Keep it to what a manager actually wants to know
- Do NOT invent items not evidenced by the log or Jira

---

### 7. Write the report file

Write the report to the path resolved in step 1.

---

### 8. Commit and push

```bash
cd /Users/rac2/rac2/weekly-log
git add -A
git commit -m "YYYY-MM-DD - weekly-report [company]"
git push
```

Use the actual Friday date and company in the commit message.

---

### 9. Confirm

Print the full report to the terminal so the user can review it.
