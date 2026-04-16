# Weekly Plan — Generate Weekly Status & Plan Report

Generate a Monday-style weekly status report by reading the current day's log, querying Jira for all sprint assignments, and producing a Teams-ready status update.

## Format

```
**Today's Status (M/DD/YYYY):**

**What I worked on:**

- [bullet per item — concise description with Jira URL at the end]

**Plans for week:**

- [bullet per item — what will be worked on, with Jira URL]

**Any Blockers:**
[blockers or No]
```

## Arguments

- Company name: `bp`, `propark`, or `zenqms` (required — ask if not provided)
- Optional date override: e.g. `bp mar24` to generate as of a specific date

## Company mapping

| Company | File suffix | Projects to search | MCP server prefix | Jira base URL |
|---------|-------------|-------------------|-------------------|---------------|
| BP (BPCyber) | `bp` | AUT, C1, TS, MDR | `mcp__Atlassian-BPCyber-Token` | https://bpcyber.atlassian.net |
| ProPark | `propark` | LPQ, LPA, LP | `mcp__Atlassian-Propark-Token` | https://propark.atlassian.net |
| ZenQMS | `zenqms` | DOR, DTR, QA | `mcp__Atlassian-ZenQMS-Token` | https://zenqms.atlassian.net |

## User identity

| Company | Email |
|---------|-------|
| BP | rcosta@blackpointcyber.com |
| ProPark | rcosta@blackpointcyber.com |
| ZenQMS | rcosta@blackpointcyber.com |

## Steps

### 1. Resolve company, date, and log file

Parse the arguments to determine company and target date. Default to today if no date given.

Compute the Friday of the target date's week. Log file:
`/Users/rac2/rac2/weekly-log/logs/YYYY/MM/DD-[company].txt`

Read the existing log file. Find the target weekday section and extract any entries already logged for the day.

### 2. Search Jira for sprint assignments

Run the following searches **in parallel** using the company's MCP server:

**a) All tickets assigned to user in open sprints:**
```
assignee = "[user_email]" AND sprint in openSprints() AND project in ([projects]) ORDER BY status ASC, priority DESC
```

**b) Tickets in "Ready for Testing" or "In Review" assigned to user (may not be in a sprint):**
```
assignee = "[user_email]" AND status in ("Ready for Testing", "In Review", "Ready to Deploy") AND project in ([projects]) ORDER BY priority DESC
```

**c) Tickets updated today by user (to capture today's work):**
```
assignee = "[user_email]" AND updated >= startOfDay() AND project in ([projects]) ORDER BY updated DESC
```

Deduplicate across all searches.

### 3. Categorize tickets

Sort all tickets into these buckets:

- **Worked on today**: Tickets from search (c) that were updated today, plus any entries already in the day's log section. Also include tickets transitioned today (created, closed, moved to In Progress).
- **Plans for week**: All tickets in **Open** or **In Progress** status from the sprint. These represent the week's planned work. Exclude closed/done tickets. Also exclude parent Epics — only list concrete Stories/Tasks/Bugs that represent actual deliverable work. Epics are containers, not plan items.
- **Blocked / Needs More Info**: Tickets in "Needs More Information" or with blockers mentioned in comments.

### 4. Confirm with user before generating

Before generating the final report, present a summary of what was found:
- List "What I worked on" items
- List "Plans for week" items
- List any blocked items

Ask: "Is there anything missing — work you did today or plan to do this week that isn't captured here?"

Wait for user confirmation. If the user adds items, incorporate them.

### 5. Format the report

Use plain text only — no markdown headings, no `##`, no `**bold**` except section headers. This is meant to be copy-pasted directly into Teams.

Group items under plain-text workstream headers inside each section. A workstream is a coherent area of work (e.g. "Code reviews", "MDR manual testing", "Test automation", "Linux Distro Automation"). If you are unsure how to group items, ask the user before generating.

```
**Today's Status (M/DD/YYYY):**

**What I worked on:**

Workstream label
- [concise item + Jira URL]
- [concise item + Jira URL]

Another workstream label
- [concise item + Jira URL]

**Plans for week:**

Workstream label
- [concise item + Jira URL]

Another workstream label
- [concise item + Jira URL]

**Any Blockers:**
No
```

Rules:
- Use `**bold**` for the top-level section headers only (`**What I worked on:**`, `**Plans for week:**`, `**Any Blockers:**`)
- Workstream labels are plain text, no bold, no bullet — just the label on its own line followed by a blank line and its bullets
- Each item is a bullet point (`- `) under its workstream label
- Keep item descriptions concise — key outcome or action, not a full sentence of technical detail
- End each bullet with the Jira browse URL: `https://[company].atlassian.net/browse/TICKET-ID` (omit if no ticket)
- For "What I worked on": lead with the action or outcome
- For "Plans for week": lead with the intent ("Continue…", "Follow up on…", "Start…")
- Blank line between workstream label and its bullets, and between workstream groups
- If a log entry contains an `[AI: ...]` marker, include it inline on that bullet
- If you cannot determine the right workstream grouping for an item, ask the user before generating the report

### 6. Write the report file

Save to:
- Path: `/Users/rac2/rac2/weekly-log/weekly-plans/YYYY/MM/DD-[company].md`
  - `YYYY/MM` = year and month of today's date
  - `DD` = today's day (zero-padded)
  - Create the directory if it does not exist

### 7. Output

Print the formatted report to the console and confirm the file path written.

## Example output

```
**Today's Status (3/23/2026):**

**What I worked on:**

MDR manual testing
- Created manual testing ticket for C1-6192 (trigger-to-notification-channel mapping in event-signal); test plan covers TriggerDefinitionRegistry init, 43 trigger resolutions, E2E Kafka flow https://bpcyber.atlassian.net/browse/AUT-3356
- Created Mac Agent 0.11.10 REGRESSION testing ticket (requested by Don Hanson) https://bpcyber.atlassian.net/browse/AUT-3357

Test automation
- Closed QA Sprint 6 Legacy Portal Maintenance https://bpcyber.atlassian.net/browse/AUT-3326

**Plans for week:**

MDR manual testing
- Manual testing for C1-6192 — TriggerDefinitionRegistry, 43 trigger resolutions, E2E Kafka flow https://bpcyber.atlassian.net/browse/AUT-3356
- Mac Agent 0.11.10 REGRESSION on macOS VM — install, config, startup log, malware detection https://bpcyber.atlassian.net/browse/AUT-3357
- Continue test plan for C1-5743 — ITDR New User Behavior Detections https://bpcyber.atlassian.net/browse/AUT-3142

Linux Distro Automation
- Add Debian 11/12/13 and Oracle Linux 8/9/10 to OS Image Library https://bpcyber.atlassian.net/browse/AUT-3278

**Any Blockers:**
No

---
Saved to weekly-plans/2026/03/23-bp.md
```
