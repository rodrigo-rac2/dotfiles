# Add Xray Tests — Create Manual Test Tickets from a Test Plan

Create manual Xray test tickets in Jira from a test plan ticket, link them to an epic, and guide the user to organize them into an Xray folder.

> **Important:** This skill is for **manual tests only**. It creates individual Jira test tickets from test cases described in a test plan issue.

## Arguments

Pass all required inputs as a single string, in any order:

```
/add-xray-tests epic=C1-5743 plan=C1-6401 labels=C1_MDR,C1_UITest company=bp
/add-xray-tests epic=LPQ-1200 plan=LPQ-1300 labels=LPQ_Manual company=propark
```

Required:
- `epic=TICKET-KEY` — The epic to link all test tickets to (via "is tested by")
- `plan=TICKET-KEY` — The test plan ticket containing the test case descriptions
- `labels=label1,label2` — One or more labels to apply to every created test ticket
- `company=bp|propark` — Which Jira instance to use

If any required argument is missing, ask the user before proceeding.

## Company mapping

| Company | MCP server | Issue type | Jira base URL | User account ID |
|---------|-----------|------------|---------------|-----------------|
| `bp` | `mcp__Atlassian-BPCyber-Token` | `Xray Test` | https://bpcyber.atlassian.net | `712020:86be7538-4d0e-4c24-add5-d3caa1bf3dcb` (rcosta@blackpointcyber.com) |
| `propark` | `mcp__Atlassian-Propark-Token` | `Test` | https://propark.atlassian.net | username `rodrigo.costa` (rodrigo.costa@projectinflection.com) |

## Steps

### 1. Fetch the test plan

Call `jira_get_issue` on the test plan ticket (`plan=`). Read the full description to extract every test case.

Each test case should have:
- A **title** (use as the Jira summary)
- **Test steps** (numbered actions)
- **Expected results**
- **Preconditions** (if any)
- **Priority** (if stated; default to Medium)

If the test plan groups tests by area (e.g. "File Activity Parser", "SNAP UI"), note the area — it will be used in the description's Related Tickets / context section.

### 2. Create the test tickets

For each test case, call `jira_create_issue` with:

```json
{
  "project_key": "<project from epic key, e.g. QA or LPQ>",
  "summary": "<test case title>",
  "issue_type": "<Xray Test for bp, Test for propark>",
  "description": "<see format below>",
  "assignee": "<user account ID for the company>",
  "reporter": "<user account ID for the company>",
  "additional_fields": {
    "labels": ["<label1>", "<label2>"]
  }
}
```

**For BP**, create tickets in the **QA project** (not C1 or TS).
**For ProPark**, create tickets in the same project as the epic (e.g. LPQ).

**Description format** — use bold headers, plain text body:

```
*Test Objective*
<1-2 sentence description of what this test validates>

*Preconditions*
<list any environment/data setup required, or "None">

*Test Steps*
1. <step>
2. <step>
...

*Expected Results*
<what should happen when all steps are followed correctly>

*Related Tickets*
<epic key> — <epic summary>
<plan key> — <plan summary>

*Priority*
<High / Medium / Low>
```

**Run ticket creation in parallel** — fire all `jira_create_issue` calls at once. If the batch fails, fall back to individual sequential calls.

### 3. Link all tickets to the epic

After all tickets are created, call `jira_create_issue_link` for each one:

```json
{
  "link_type": "Test",
  "inward_issue_key": "<epic key>",
  "outward_issue_key": "<newly created ticket key>"
}
```

This creates the relationship: epic **"is tested by"** test ticket.

Run all link calls in parallel.

### 4. Output a summary and JQL query

After all tickets are created and linked, output:

1. **Count**: "Created X test tickets: QA-XXXXX – QA-YYYYY"
2. **JQL query** to select all created tests:

```
project = <project> AND issuetype = "<Xray Test|Test>" AND labels = <primary_label>
```

If multiple labels were provided, use the most specific one (the one least likely to exist on other tickets).

3. **Instructions to move into an Xray folder:**

---

To organize these tests into an Xray folder in Jira:

1. Open the Xray Test Repository in your Jira project.
2. Right-click the target folder (or create a new one for this epic/feature).
3. Select **"Add Tests"**.
4. In the dialog that opens, switch to the **"JQL"** tab.
5. Enter the JQL query above and press Search.
6. Select all results and click **Add**.

---

## AI assistance note

Add an `[AI: ...]` inline note to the daily log entry when using this skill, since Claude is doing the bulk of the work (extracting test cases, creating tickets, linking to epic).

Example log entry:
```
- C1-6401 — Created 69 manual Xray test tickets in QA project for MDR New Detections epic (C1-5743); all linked with "is tested by". [AI: Claude Code extracted test cases, created all tickets, and linked to epic.] https://bpcyber.atlassian.net/browse/C1-6401
```
