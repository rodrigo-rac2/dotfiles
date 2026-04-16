# Code Review — Deep Human-Like PR Review

Perform a thorough, human-like code review of a GitHub Pull Request. Analyze the full repository context, post inline comments directly to GitHub, and submit a review decision.

## Arguments

`$ARGUMENTS` may be:
- A full PR URL: `https://github.com/org/repo/pull/123` or `https://github.company.com/org/repo/pull/123`
- A PR number only (e.g. `42`) — in this case, infer the repo from `git remote get-url origin` in the current working directory
- Empty — run `gh pr view --json number,url` in the current working directory to find the open PR for the current branch. If found, use it. If not found, stop and tell the user no PR could be found for the current branch.

---

## Phase 1 — Parse the PR reference

From the URL or current repo remote, extract:
- `GH_HOST` — the GitHub hostname (e.g. `github.com`, `github.bpcs.com`)
- `GH_ORG` — the organization or owner
- `GH_REPO` — the repository name
- `PR_NUMBER` — the pull request number

All `gh` commands must include `--hostname $GH_HOST` when the host is not `github.com`.

Run `gh auth status` to confirm the host is authenticated. If it is not, tell the user: "I'm not authenticated to `$GH_HOST`. Please run `gh auth login --hostname $GH_HOST`." and stop.

---

## Phase 2 — Clone the repository

Always clone a fresh copy for the review. This avoids disrupting any locally checked-out branch and allows parallel reviews to run simultaneously.

Read `~/.claude/code-review-config.json`. If the file does not exist, create it:
```json
{
  "host_dir_map": [
    { "pattern": "github.bpcyber.com", "reviews_dir": "~/blackpoint/code-reviews" },
    { "pattern": "github.com/blackpointcyber", "reviews_dir": "~/blackpoint/code-reviews" },
    { "pattern": "github.com/propark", "reviews_dir": "~/propark/code-reviews" },
    { "pattern": "github.com/zenqms", "reviews_dir": "~/zenqms/code-reviews" },
    { "pattern": "github.com/rac2", "reviews_dir": "~/rac2/code-reviews" }
  ]
}
```

Match `$GH_HOST/$GH_ORG` against entries in `host_dir_map` (in order). Use the first match's `reviews_dir`. If nothing matches, default to `~/rac2/code-reviews`, add `{ "pattern": "$GH_HOST/$GH_ORG", "reviews_dir": "~/rac2/code-reviews" }` to the config automatically, and proceed without asking the user.

Set `CLONE_DIR = <resolved_reviews_dir>/$GH_REPO-$PR_NUMBER`.

Create the parent reviews directory if it does not exist: `mkdir -p "<resolved_reviews_dir>"`.

Clone: `gh repo clone $GH_ORG/$GH_REPO "$CLONE_DIR" -- --depth=100` (include `--hostname $GH_HOST` if needed).

Then checkout the PR branch from inside `$CLONE_DIR`: `gh pr checkout $PR_NUMBER --force`.

Set `REPO_DIR = $CLONE_DIR`.

---

## Phase 3 — Fetch PR metadata and diff

### 3.0 Merge check (abort if already merged)

Before anything else, fetch the PR state:
```
GH_HOST=$GH_HOST gh pr view $PR_NUMBER --json state,mergedAt,mergedBy
```

If `state == "MERGED"`, stop immediately and tell the user:

> "PR #$PR_NUMBER is already merged. No review needed."

Do not proceed past this point.

### 3.1 Fetch metadata (run in parallel)

Run in parallel from inside `$REPO_DIR`:

1. `gh pr view $PR_NUMBER --json title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,labels`
2. `gh pr diff $PR_NUMBER` — full unified diff of the PR
3. `gh pr view $PR_NUMBER --json comments,reviews` — top-level comments and review summaries
4. `gh api repos/$GH_ORG/$GH_REPO/pulls/$PR_NUMBER/comments --hostname $GH_HOST` — all existing inline review comments with their bodies, paths, and line numbers
5. `gh api user --hostname $GH_HOST --jq .login` — get my own GitHub username for this host

Store the full text of every existing comment (both top-level and inline). Before finalising any finding in Phase 6, check whether the same issue has already been raised by another reviewer on the same file and line range. If it has, skip that finding entirely — do not repeat feedback that is already on the PR.

Store:
- `PR_TITLE`, `PR_BODY`, `PR_AUTHOR`
- `LINES_ADDED`, `LINES_DELETED`
- `CHANGED_FILES` list
- Full diff text
- `MY_LOGIN` — my username on this host

Parse `PR_TITLE` and `PR_BODY` for:
- Ticket IDs: patterns like `C1-\d+`, `TS-\d+`, `AUT-\d+`, `LPQ-\d+`, `DOR-\d+`, `QA-\d+`, `#\d+`
- Any stated motivation, design decisions, or scope description the author provided

**Re-review detection**: From the reviews list fetched in step 3, filter to reviews where `user.login == MY_LOGIN` and `state` is not `PENDING`. If any exist, this is a re-review. Set `IS_RE_REVIEW = true` and `LAST_REVIEW_COMMIT = commit_id` of the most recent such review (highest `submitted_at`).

---

## Phase 3.5 — Re-review mode (skip if IS_RE_REVIEW is false)

If `IS_RE_REVIEW = true`, the review scope changes completely. You are not reviewing the whole PR again — you are reviewing only what changed since you last looked, and verifying your previous comments were addressed.

### 3.5a. Get the incremental diff

Run: `git diff $LAST_REVIEW_COMMIT..HEAD`

This is the only diff used for finding new issues in Phase 5. Store it as `INCREMENTAL_DIFF`. Recalculate `LINES_ADDED` and `LINES_DELETED` from this diff — the budget in Phase 6 is based on these numbers, not the full PR diff.

If the incremental diff is empty (no new commits since my last review), skip Phases 5 and 6 entirely and go straight to Phase 3.5b — there is nothing new to comment on.

### 3.5b. Check resolution status of my previous inline comments

From the all-comments list fetched in Phase 3 step 4, filter to comments where `user.login == MY_LOGIN`. These are my previous inline comments.

For each of my previous comments, determine its status using these signals:

**ADDRESSED** — the issue was fixed. Signals (any one is enough):
- The file and line region (±10 lines) appears as changed in `INCREMENTAL_DIFF`
- A reply exists after my comment (same `path`, same `original_line`, different `user.login`) containing words like "addressed", "fixed", "done", "updated", "changed"
- My comment's `line` no longer exists in the current file (code was removed/rewritten)

**ACKNOWLEDGED** — dev replied but the code was not changed. A reply exists but the code region is unchanged in `INCREMENTAL_DIFF`.

**STILL_OPEN** — no reply, no code change at that location.

Build a summary list:
```
PREVIOUS_COMMENTS_STATUS = [
  { body_snippet, path, line, status: ADDRESSED | ACKNOWLEDGED | STILL_OPEN },
  ...
]
```

This summary is used in Phase 7 to write the overall review comment, and informs the review decision in Phase 8.

---

## Phase 4 — Deep repository analysis

This phase determines the review quality. Be thorough — do not skip sections.

### 4a. Coding standards and project conventions

Read every available standards document, in priority order. These findings become **T1 (highest priority)** violations when the PR breaks them.

- `.github/CONTRIBUTING.md`, `.github/pull_request_template.md`, `.github/CODEBASE.md`
- Root `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `STYLE_GUIDE.md`
- `docs/` directory — read all markdown files
- Linter/formatter configs: `.eslintrc*`, `.prettierrc*`, `pyproject.toml`, `ruff.toml`, `setup.cfg`, `.rubocop.yml`, `golangci.yml`, `checkstyle.xml`, `tslint.json`, `.stylelintrc`
- Test conventions: read 2–3 existing test files in the same module as the changed files — understand naming patterns, assertion style, coverage expectations
- `SECURITY.md` or any security policy file

### 4b. Existing code patterns

For each file modified in the PR, read the **full file** (not just the diff) to understand:
- Naming conventions in use
- Error handling patterns
- How similar features were previously implemented
- Any TODOs, FIXMEs, or known debt nearby the change

Also read 2–3 sibling files in the same directory to calibrate style expectations.

### 4c. Recent git history

- `git log --oneline -30` — understand commit style, recent focus areas
- `git log --oneline --follow -- <each_changed_file>` — history of each touched file
- `git shortlog -s -n -10` — most active contributors (helps calibrate seniority expectations)

### 4d. External context (fetch all applicable)

**Jira tickets**: For each ticket ID found in the PR title, body, or branch name, look it up using the matching MCP server:
- `C1-`, `TS-`, `AUT-`, `MDR-` → `mcp__Atlassian-BPCyber-Token__jira_get_issue`
- `LPQ-`, `LPA-`, `LP-` → `mcp__Atlassian-Propark-Token__jira_get_issue`
- `DOR-`, `DTR-`, `QA-`, `C87-` → `mcp__Atlassian-ZenQMS-Token__jira_get_issue`
- GitHub issues (`#123`) → `gh issue view 123`

From each ticket, read: description, acceptance criteria, any linked Confluence pages.

**External URLs**: Scan README and docs files for URLs pointing to style guides, architecture wikis, API docs, or Confluence. Fetch and read each one using the WebFetch tool.

**Confluence pages** linked from Jira tickets: use `mcp__Atlassian-*__confluence_get_page` on any Confluence page IDs or URLs found.

---

## Phase 5 — Identify all findings

**In re-review mode**: use `INCREMENTAL_DIFF` instead of the full PR diff. If `INCREMENTAL_DIFF` is empty (no new commits), skip this phase entirely — go to Phase 7 directly and write an overall comment based solely on the previous comments status from Phase 3.5b.

Analyze the diff against everything learned in Phase 4. For each changed hunk, identify every issue, smell, or improvement opportunity. Tag each with a priority tier:

- **T1** — violates a repo-specific standard or convention found in Phase 4a
- **T2** — violates general coding standards (SOLID, DRY, clear naming, separation of concerns, etc.)
- **T3** — code quality concern: security vulnerability, injection risk, missing auth check, performance issue, missing test, poor reusability, brittle coupling
- **T4** — violates company/project quality requirements found in Jira tickets or Confluence docs

For each finding, record:
- The file path and the specific line number (right-hand side of the diff)
- The tier
- A draft comment (written per the comment rules below)
- Whether a code suggestion block is possible and helpful

### Single Responsibility Principle check (always run)

Evaluate the PR as a whole: does it do exactly one thing? A PR that combines a refactor + a feature, or a bug fix + an unrelated cleanup, violates SRP. If this is the case, add one additional finding (regardless of budget) at the file level or the most representative changed file, noting how the PR should be split.

---

## Phase 6 — Calculate comment budget and select top findings

### Budget calculation

```
weight = floor(LINES_ADDED / 75) + floor(LINES_DELETED / 25)
```

Map weight to budget:

| Total lines changed (added + deleted) | Comment budget |
|---|---|
| < 200 | 1–2 |
| 200–400 | 2–4 |
| > 400 | 3–6 |

Hard cap: **6 inline comments** (the SRP comment, if applicable, is additional and does not count against this cap).

### Selection order

From all findings, select up to the budget limit in this priority order:
1. T1 findings (repo standards violations)
2. T2 findings (general standards)
3. T3 findings (security, quality, reliability)
4. T4 findings (company/project requirements)

Within a tier, prefer findings that are: most actionable, have a clear code suggestion, and cover the most impactful location.

---

## Phase 7 — Write the comments

### Inline comment rules (non-negotiable)

- **Start the first sentence with a lowercase letter** — unless the first word is "I" or a proper noun (class name, library name, etc.)
- **Maximum 2 lines** of text per comment (a suggestion block does not count toward this limit)
- **No headers, no bullet lists, no bold/italic formatting** — write in plain flowing prose
- **No em dashes (`—`) and no semicolons (`;`)** — these read as AI-generated. Replace them with periods or commas. "the fix is focused. Two fields were missing." not "the fix is focused — two fields were missing."
- **Human and direct** — write as a senior engineer speaking to a teammate. Example tone: *"this method is doing two jobs at once. pulling the validation out into its own function would make it much easier to test in isolation."*
- **Constructive** — never shame, always explain why and how to improve
- **Vary the openings** — do not start multiple comments with the same phrase
- Where a concrete fix is possible, include a **GitHub suggestion block**:
  ````
  ```suggestion
  <replacement code lines>
  ```
  ````
  Only suggest a change if it is complete and directly applicable (single-line or small multi-line substitution). Do not suggest partial or speculative changes.

### Overall review comment rules

Write **2 sentences max**. Same tone and punctuation rules as inline comments (no em dashes, no semicolons, lowercase start, no headers, no lists). Cover what matters most: the main concern or a genuine positive, and the path forward. Drop anything that doesn't earn its place.

**In re-review mode with no new commits (INCREMENTAL_DIFF is empty)**: write exactly one sentence. If all previous comments are ADDRESSED, just say "lgtm" — nothing more. If some are STILL_OPEN or ACKNOWLEDGED, name them briefly: "the timeout fix looks good, but the trailing period on Fortigate is still there."

---

## Phase 8 — Determine review decision

**APPROVE**: The PR is correct, safe, and ready to merge. Minor notes exist but none block shipping. In re-review mode with no new commits and all previous comments ADDRESSED, always approve — no hesitation.

**REQUEST_CHANGES**: One or more findings that must be addressed before this can merge. Use this for security issues, broken logic, test gaps on critical paths, significant standard violations, or any STILL_OPEN comment from a prior review that was not addressed.

**REJECT**: The PR adds no value, makes things worse, or is fundamentally wrong in its approach. Post a `REQUEST_CHANGES` review with the overall comment explaining why the approach is wrong and what should be done instead. Do not approve or silently skip — always post the review.

For approve and request-changes decisions: be constructive and team-oriented. A PR with solvable problems should always get `REQUEST_CHANGES`, not rejection. Consider the PR's intent, the author's effort, and the team's norms.

---

## Phase 9 — Post the review

### 9a. Prepare the payload

For each selected inline comment, determine:
- `path`: relative file path from repo root
- `line`: the right-hand side (new file) line number where the comment applies
- `side`: always `"RIGHT"` for comments on added/changed lines; use `"LEFT"` only for comments on removed lines
- `body`: the formatted comment text (including suggestion block if applicable)

Build the full review payload JSON:
```json
{
  "body": "<overall review comment>",
  "event": "<APPROVE|REQUEST_CHANGES>",
  "comments": [
    {
      "path": "src/foo/bar.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "this variable name is too generic..."
    }
  ]
}
```

Write this JSON to `/tmp/code-review-payload-$PR_NUMBER.json`.

### 9b. Submit

```bash
gh api repos/$GH_ORG/$GH_REPO/pulls/$PR_NUMBER/reviews \
  --method POST \
  --hostname $GH_HOST \
  --input /tmp/code-review-payload-$PR_NUMBER.json
```

Then delete the temp payload: `rm /tmp/code-review-payload-$PR_NUMBER.json`.

If the API call fails, output the full payload to the user with the error message so they can investigate or post manually.

---

## Phase 10 — Cleanup and report

1. Delete the clone directory: `rm -rf "$CLONE_DIR"`
2. Output a brief summary to the user:

```
PR #<number>: <title>
Author: <username>
Changes: +<additions> / -<deletions> across <N> files
Inline comments posted: <N> (+ SRP comment if applicable)
Review decision: <APPROVE | REQUEST_CHANGES | REJECT (manual)>
Tickets/context used: <list of ticket IDs and URLs fetched>
```

---

## Config self-update rule

If during this review you encounter a `$GH_HOST/$GH_ORG` combination that does not match any entry in `~/.claude/code-review-config.json`, automatically add `{ "pattern": "$GH_HOST/$GH_ORG", "reviews_dir": "~/blackpoint/code-reviews" }` to the config and proceed without asking the user.
