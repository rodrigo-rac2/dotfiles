# Create Bug — Blackpoint (C1 Project)

Create a bug ticket in the CompassOne Jira project (C1) following the standard Blackpoint bug description table format.

## How to use this skill

1. **Parse arguments** — extract the fields from the arguments or ask the user for any missing required ones.
2. **Create the issue** using `mcp__Atlassian-BPCyber-Token__jira_create_issue` with the fields below.
3. **Report back** with the new ticket key and URL.

## Required fields (ask if not provided)

| Field | Notes |
|---|---|
| `summary` | One-line ticket title |
| `component` | Jira component name (e.g. `Notification`, `Asset Inventory`, `Policies`) |
| `issue_summary` | Short description of the bug for the Issue Summary table row |
| `detailed_description` | What was being tested / context when the bug was found |
| `steps_to_reproduce` | Numbered steps — write as a single line using "1. step. 2. step." format (no newlines) |
| `actual_behavior` | What actually happened |
| `expected_behavior` | What should have happened |

## Optional fields (use defaults if not provided)

| Field | Default |
|---|---|
| `priority` | `Medium` |
| `fix_version` | `Staging` |
| `label` | `MDR` |
| `error_generated` | `No UI error.` |
| `device` | `N/A` |
| `log` | Leave blank if not provided |

## Issue creation parameters

```
project_key: C1
issue_type: Bug
components: <component>
additional_fields: {
  "priority": {"name": "<priority>"},
  "fixVersions": [{"name": "<fix_version>"}],
  "versions": [{"name": "<fix_version>"}],
  "customfield_10188": {"value": "Integrations - Notifications (PSA)"},  ← only if component is Notification
  "labels": ["<label>"]
}
```

## Description format (critical — follow exactly)

The description MUST be a Jira table with each row on a single line. Do NOT use newlines (`\n`) inside any cell — use `. ` (period + space) to separate numbered steps and sentences inline.

```
|**Issue Summary**|<issue_summary>|
|**Device(s) if applicable**|<device>|
|**Detailed description of the task**|<detailed_description>|
|**Error generated**|<error_generated>|
|**Steps to reproduce**|<steps_to_reproduce — all on one line, e.g.: 1. Do X. 2. Do Y. 3. Check Z.>|
|**Actual Behavior**|<actual_behavior>|
|**Expected Behavior**|<expected_behavior>|
|**Log (attach if available)**|<log>|
```

## Rules

- Each table row MUST be on a single line — no embedded newlines inside cells.
- Steps to reproduce: format as `1. Step one. 2. Step two. 3. Step three.` all inline.
- If the component is `Notification`, include `"customfield_10188": {"value": "Integrations - Notifications (PSA)"}` in additional_fields.
- For other components, omit `customfield_10188` to avoid field validation errors.
- The Team field (customfield_10001) cannot be set via API — remind the user to set it manually in the Jira UI to "Managed Detection & Response" after creation.
- Always use `mcp__Atlassian-BPCyber-Token` (not Propark or ZenQMS).
- After creation, print the ticket key and direct URL: `https://bpcyber.atlassian.net/browse/<KEY>`

## Arguments

Arguments can be provided as free-form text describing the bug. Extract the relevant fields from the description.

Examples:
- `/create-bug-blackpoint Notifications - Mass Download email shows wrong subject. Component: Notification.`
- `/create-bug-blackpoint` (then ask for each field interactively)

If the user provides a Jira ticket key as context (e.g. "related to AUT-3438"), mention it in the Log field.
