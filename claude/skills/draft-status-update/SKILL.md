---
name: draft-status-update
description: Use when the user wants to write a Teams message, needs to report progress to the team, asks for a status update draft, or says "write a teams message" / "post an update". Common for template spec releases, Azure infrastructure changes, or VM deployment milestones.
allowed-tools: Read
---

# Draft Teams Status Update

## Message format (this team's style)
- **Short bold subject line** — no emoji
- 1-2 sentence context paragraph (what was being worked on and why)
- "What happened:" or "What was fixed:" — bullet list of concrete actions
- "Next steps:" — numbered list
- Tone: professional but direct, not over-formal, first person

## Template spec release message template
```
**Template Spec v{version} — {short description}**

Hey team, quick update on the v{version} template spec deployment ({what it adds}).

What was done:
• {action 1}
• {action 2}

What's still pending:
• {pending item}

Next steps:
1. {next 1}
2. {next 2}
3. Fix automated deploys from platform-microsoft-365 — once the pipeline properly uploads ARM templates and CSEs to blob storage on merge, we can move this to maintenance mode
```

## Standard next steps for ongoing v1.6.1 / v1.6.x rollout
1. Update remaining Template Specs to v1.6.1 (list any still at 1.6.0)
2. Add additional Linux versions in a future release (v1.6.2 or v1.7.0 — TBD)
3. Fix automated deploys from platform-microsoft-365

## VM link format (for referencing a deployed VM)
`https://portal.azure.com/#@BlackpointCyberDev.onmicrosoft.com/resource/subscriptions/8eb6a56e-e1af-430a-9eec-2f4d436eb23c/resourceGroups/eus2-engineering-virtualmachines-rg/providers/Microsoft.Compute/virtualMachines/{vm-name}/overview`

## Weekly log format (4 lines max per accomplishment)
Each entry: what was accomplished → what was discovered/fixed → outcome → what's next.
Keep entries to 3-4 sentences. No bullet points in the weekly log — prose only.
