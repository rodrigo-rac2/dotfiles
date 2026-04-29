# QA Stamp — Post Test Results to Jira

Post a structured QA Stamp Comment to a Jira ticket documenting test results.

## How to use this skill

1. **Identify the ticket key** from the arguments or ask the user.
2. **Gather test results** from the current conversation context (consumer logs, event IDs, test outcomes). If context is insufficient, ask the user to describe what was tested and what passed or failed.
3. **Select the correct Atlassian MCP server** — use the one that matches the ticket's Jira instance (e.g. `mcp__Atlassian-BPCyber-Token__jira_add_comment` for bpcyber.atlassian.net). If unsure, look for MCP tools whose name contains the org name from the ticket URL, or ask the user.
4. **Post the comment** using `jira_add_comment` with the structured format below.

## QA Stamp Comment format

```
Testing results: <PASS | FAIL | PARTIAL>

ENV: <environment, e.g. staging, production>

Description: <1–2 sentence summary of what was tested and how>

----

**<Test case title>**

- <key detail>: `<value>`
- <key detail>: `<value>`
- Result: ✅ <what passed> / ❌ <what failed and why>

----

**<Next test case title>**

- ...
- Result: ✅ / ❌ ...

----

**Screenshots**

Attach the following files to this comment (from `.playwright-mcp/` in the CompassOneQA repo):

- `page-{timestamp}.png` — [brief description of what is shown]
- `page-{timestamp}.png` — [brief description of what is shown]

----

AI Assistance
Claude Code (Anthropic) supported this QA cycle: test scenario design, browser automation, results analysis, and Jira comment authoring.
```

## Rules

- Mirror the level of detail of the tests actually performed — don't invent test cases.
- Use inline code (backticks) for event IDs, event types, parser names, log messages, and field values.
- Each `----` section is one test case or scenario. Group related assertions under the same section.
- If overall result is FAIL, explain the failure clearly in the relevant section and note any follow-up action.
- Keep the tone factual and concise — this is a QA record, not a narrative.
- Always include the AI Assistance section at the end — this is required for management AI usage reporting.
- **Screenshots**: If screenshots were taken during testing (files in `.playwright-mcp/`), always include the Screenshots block before AI Assistance. List each file by name with a one-line description of what it shows. If no browser automation was used, omit the Screenshots block.

## After posting the stamp — ticket lifecycle

After the comment is posted, always handle the ticket status and assignment:

**If result is PASS:**
1. Transition the ticket to **Ready for Deployment**. The path through the C1 workflow is: current status → In Progress (51) → Ready for Testing (41) → Testing/In Testing (81) → Ready for Deployment (91). Skip steps already passed (e.g. if the ticket is already in Ready for Testing, start from there).
2. Reassign the ticket to the developer who worked on it (the reporter, or whoever last moved it to Ready for Testing — check the issue fields).

**If result is PARTIAL or FAIL:**
Stop after posting the comment. Ask the user: "Result is [PARTIAL/FAIL] — how would you like me to handle the ticket? I can leave it in place, move it back to In Progress, or reassign it to the developer."

## Arguments

The user may pass a ticket key as the argument (e.g. `/qa-stamp C1-6128`). Use it directly.
If no argument is provided, ask: "Which Jira ticket should I post the QA stamp to?"
