# Create Manual Testing Ticket

Create a manual testing ticket on a QA board based on a source Jira ticket.

## How to use this skill

1. **Parse arguments** — extract the source ticket key, target board key, and company from the arguments or ask the user.
2. **Select the MCP server** based on the company:
   - `bp` → `mcp__Atlassian-BPCyber-Token`
   - `propark` → `mcp__Atlassian-Propark-Token`
   - `zenqms` → `mcp__Atlassian-ZenQMS-Token`
3. **Fetch the source ticket** using `jira_get_issue` (with `fields: "*all"`) to get the summary, description, and epic link.
4. **Create the manual testing ticket** on the target board using `jira_create_issue`:
   - `project_key`: the target board key (e.g. `AUT`, `TA`)
   - `summary`: `Manual Testing — <SOURCE-KEY> — <original source summary>` (never copy verbatim without the prefix)
   - `issue_type`: `Story`
   - `assignee`: the current user (`rcosta@blackpointcyber.com` for bp; use `jira_get_user_profile` with `account_id: "me"` if email unknown)
   - `description`: structured description linking back to the source ticket (see format below)
   - `additional_fields`: include story points as `{"customfield_10024": 1}` (this is the "Story Points" field in BPCyber Jira — verified `customfield_10024`)
5. **Link to the epic** using `jira_link_to_epic`:
   - For `bp` / `AUT` board: inspect the source ticket's domain. If it is MDR-related (summary contains `[MDR]`, or epic link points to an MDR epic in C1/AUT), link to **AUT-3192** ("Managed Detection & Response E2E Testing").
   - For other domains or companies, search for a matching epic on the target board using `jira_search` (`issuetype = Epic AND project = <TARGET-BOARD> AND summary ~ "<domain keyword>"`). If none found, skip and notify the user.
6. **Find the active sprint** on the target board using `jira_get_agile_boards` (filter by project key) then `jira_get_sprints_from_board` with `state: "active"`. For `AUT` board on `bp`, use board ID **11** (Quality Team Board). Pick the sprint whose name contains "QA" — if ambiguous, pick the most recently started one.
7. **Add the ticket to the sprint** using `jira_add_issues_to_sprint`.
8. **Report back** with the new ticket key, URL, epic linked, and sprint added to.

## Description format

```
Manual testing for <SOURCE-TICKET-KEY>.

<1–2 sentence summary of what needs to be validated, derived from the source ticket's scope and acceptance criteria.>

**<Source issue type (Story/Bug/Task)>:** [<SOURCE-TICKET-KEY>](<source ticket URL>)
```

## Rules

- Always fetch the source ticket first — never guess the summary or scope.
- Title MUST start with `Manual Testing — <SOURCE-KEY> — ` so the ticket is self-identifying in board views.
- Issue type is always `Story`.
- Derive the test description from the source ticket's Scope and Acceptance Criteria sections, not the Definition of Done.
- If the source ticket description is a blank template (no content filled in), write a one-sentence description based on the summary title alone.
- Assign to the current user (the one running the skill).
- Always link to the appropriate epic — do not skip this step without notifying the user.
- Always add to the active QA sprint — if no active sprint exists, say so and skip that step.
- Story points: set to 1 via `customfield_10024` (verified field ID for BPCyber Jira "Story Points").
- If the target board project key is not provided, ask: "Which board should I create the ticket on?"

## Arguments

Arguments follow the pattern: `from <SOURCE-TICKET> on <BOARD-KEY> for <company>`

Examples:
- `from C1-6616 on AUT for bp`
- `from AI-111 on TA for propark`
- `from DOR-55 on QAT for zenqms`

If the company is not provided but can be inferred from the source ticket prefix (e.g. `C1-`, `TS-`, `AUT-` → bp; `LPQ-`, `LP-` → propark; `DOR-`, `DTR-` → zenqms), infer it silently.
If arguments are missing, ask: "Please provide the source ticket, target board, and company (bp, propark, or zenqms)."
