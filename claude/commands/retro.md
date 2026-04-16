# Retro — Generate Sprint Retrospective

Generate a sprint retrospective based on the weekly work logs for the current and previous week.

## Format

```
What went well
- [item]

What could be improved
- [item]

Action items
- [item]
```

## Arguments

- Company name: `bp`, `propark`, or `zenqms` (required — ask if not provided)
- Optional `--week=prev` to base the retro on the previous week only (default: current + previous week)

## Steps

### 1. Determine the company and log files

Map company argument to log file suffix: `bp`, `propark`, or `zenqms`.

Resolve log file paths:
- Compute the Friday of the current week from today's date → `logs/YYYY/MM/DD-[company].txt`
- Compute the Friday of the previous week → `logs/YYYY/MM/DD-[company].txt`
- Read both files

### 2. Read the logs

Read all daily entries from both log files. Collect:
- Tickets worked, closed, escalated, or blocked
- Bugs found, test failures, unexpected rework
- Tooling or process improvements made
- Items that required escalation or were left unresolved
- Any mentions of "blocked", "failed", "escalated", "unexpected", "rework", "waiting on", "unclear"

### 3. Generate retro items

Analyze the full two-week picture and produce items in three categories. Within each category, group related items under plain-text workstream labels (e.g. "MDR testing", "CI / pipeline", "Code reviews") when there are items from multiple areas. Skip the label if all items are from the same workstream.

**What went well**
- Highlight completed features, successful test coverage, proactive bug catches, tooling wins, good cross-team collaboration
- Be specific: reference ticket IDs, PR numbers, or outcomes where helpful

**What could be improved**
- Identify friction points: late discoveries, unclear specs, infra gaps, test environment limitations, tasks that rolled over
- Frame as questions or observations, not blame — e.g. "Do we have a way to X?" or "Was Y fully specced before QA started?"

**Action items**
- Concrete follow-ups implied by the "improve" items
- Each should be a specific, actionable next step (not a vague goal)

Keep items concise — retro cards are meant to spark conversation, not document everything.

### 4. Write the retro file

Save to:
- Path: `/Users/rac2/rac2/weekly-log/retros/YYYY/MM/DD-[company].md`
  - `YYYY/MM` = year and month of today's date
  - `DD` = today's day (zero-padded)
  - Create the directory if it does not exist
- Format: Markdown with `##` section headers and bullet points (this file is for reference, not copy-paste)

### 5. Output

Print the formatted retro to the console and confirm the file path written.

## Example output

```
What went well
- Alert V2 QA covered banner UI roles, production smoke, re-grant scripts, and event polling in one sprint (C1-5948, C1-5951, C1-6170, C1-5956).
- Apollo11 CLI event sender (AUT-3304) enabled rapid local QA without needing real production events.
- C1-6211 (Pendo modal z-index conflict) caught proactively during role-based testing.

What could be improved
- Mac Agent QA (AUT-3323) ended with escalation — no controlled environment to test agent behavior when the host OS intercepts malware first.
- 10 of 22 apollo11 event types couldn't be fully verified without real production samples for detectorIds (C1-6117).

Action items
- Investigate a sandboxed malware testing environment for agent QA that bypasses host OS defenses.
- Maintain a golden sample library of real alert payloads (one per event type) in the apollo11 repo.

---
Saved to retros/2026/03/11-bp.md
```
