---
name: fix-flaky-tests-compassone
description:
  Analyzes CI/CD pipeline failures and fixes failing or flaky Playwright tests.
  Use when tests fail in GitHub Actions and need debugging. Parses error logs,
  identifies root causes (locator issues, timing problems, navigation failures,
  data dependencies), applies targeted fixes, and verifies locally. Uses
  playwright-cli for browser automation (with Playwright MCP as fallback).
  Supports parallel fixing of multiple tests.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
  - Task
  # Primary: playwright-cli (via Bash)
  # Fallback: Playwright MCP tools (when CLI is insufficient)
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_click
  - mcp__playwright__browser_type
  - mcp__playwright__browser_snapshot
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_evaluate
  - mcp__playwright__browser_wait_for
  - mcp__playwright__browser_tabs
  - mcp__playwright__browser_fill_form
  - mcp__playwright__browser_select_option
  - mcp__playwright__browser_press_key
  - mcp__playwright__browser_console_messages
  - mcp__playwright__browser_network_requests
  - mcp__playwright__browser_close
---

# Fix Flaky Tests - CI Failure Debugger & Fixer

Analyze GitHub Actions CI failures and fix failing Playwright tests through
automated log analysis, root cause identification, and iterative local
verification.

## What This Skill Does

1. **Parses CI Logs**: Extracts failing test names, error messages, stack
   traces, and environment details from GitHub Actions output
2. **Classifies Failures**: Categorizes each failure by root cause (locator,
   timing, navigation, data, environment)
3. **Investigates Codebase**: Reads failing test files, page modules, locators,
   and fixtures to understand context
4. **Applies Targeted Fixes**: Makes precise changes based on failure
   classification
5. **Verifies Locally**: Runs fixed tests locally to confirm the fix
6. **Supports Parallel Fixing**: Orchestrates up to 4 agents to fix multiple
   failing tests simultaneously

## How to Use

### Quick Start

```
> Fix the failing test from this CI run: [paste logs]
> Fix flaky test QA-155176 - it times out in CI
> These tests are failing in the pipeline: [paste logs]
```

### With Options

```
> Fix failing tests from staging environment pipeline
> Debug and fix QA-326893 - locator not found error in CI
> Fix all 3 failing tests from this GitHub Actions run: [paste logs]
```

## CompassOneQA Project Structure

### Test Organization

```
tests/new_ui/
├── tests/                      # Test spec files
│   ├── asset_inventory/        # QA-XXXXX_*.spec.ts files
│   ├── cloudPosture/
│   ├── discovery/
│   ├── notifications/
│   └── ...
├── modules/                    # Page objects (3-tier pattern)
│   ├── commons/                # GlobalCommons base class
│   │   ├── commons.ts
│   │   └── test-utils.ts
│   ├── notifications/
│   │   ├── notifications_locators.ts
│   │   ├── notifications_methods.ts
│   │   └── notifications_module.ts
│   └── ...
└── fixtures/                   # Playwright fixtures
    ├── commons/
    │   ├── common_fixtures.ts
    │   └── discovey_fixtures.ts
    └── [feature]/
        └── [feature]_fixtures.ts
```

### Key Patterns

| Aspect               | CompassOneQA Pattern                                    |
| -------------------- | ------------------------------------------------------- |
| Test files           | `tests/new_ui/tests/{feature}/QA-{ID}_*.spec.ts`        |
| Module (Page Object) | `tests/new_ui/modules/{feature}/{feature}_module.ts`    |
| Locators             | `tests/new_ui/modules/{feature}/{feature}_locators.ts`  |
| Methods              | `tests/new_ui/modules/{feature}/{feature}_methods.ts`   |
| Fixtures             | `tests/new_ui/fixtures/{feature}/{feature}_fixtures.ts` |
| Tags                 | `import { TAG } from '@utils';`                         |
| Base class           | `GlobalCommons` in `modules/commons/commons.ts`         |

### Module 3-Tier Pattern

```typescript
// 1. Locators (notifications_locators.ts)
export class NotificationsLocators {
  readonly page: Page;
  constructor(page: Page) {
    this.page = page;
  }

  addChannelBtn(): Locator {
    return this.page.getByRole('button', { name: 'Add Notification Channel' });
  }
}

// 2. Methods (notifications_methods.ts)
export class NotificationsMethods extends NotificationsLocators {
  async navigateToNotifications(tenantName: string): Promise<void> {
    // Implementation using this.locator() methods
  }
}

// 3. Module (notifications_module.ts)
export class NotificationsMdl {
  readonly locators: NotificationsLocators;
  readonly methods: NotificationsMethods;
  constructor(page: Page) {
    this.locators = new NotificationsLocators(page);
    this.methods = new NotificationsMethods(page);
  }
}
```

## Workflow Steps

### Step 1: Parse CI Logs

Extract from pasted GitHub Actions output:

- Failing test file paths
- Test IDs (QA-XXXXX format)
- Error messages and stack traces
- Environment name (staging, prod, dev)

### Step 2: Classify Failures

For each failing test, determine the root cause category:

| Category        | Indicators                                               | Common Fixes                              |
| --------------- | -------------------------------------------------------- | ----------------------------------------- |
| **Locator**     | `TimeoutError`, `locator.click`, `strict mode violation` | Update selector, use `.first()`, `.nth()` |
| **Timing**      | `Timeout`, `waitForSelector`, `30000ms`                  | Add waits, increase timeout               |
| **Navigation**  | `ERR_CONNECTION`, `net::`, `404`                         | Fix URL, add retry, check auth            |
| **Data**        | `expect(received)`, assertion failures                   | Fix test data, add setup                  |
| **Environment** | Only on specific env, config mismatch                    | Add env guards, fix config                |
| **Auth**        | `login failed`, `401`, `session`                         | Refresh auth state, fix credentials       |
| **Flaky**       | Intermittent, passes on retry                            | Add stability waits, retry logic          |

### Step 3: Investigate Codebase

For each failing test:

- Read the test spec file in `tests/new_ui/tests/{feature}/`
- Read referenced modules in `tests/new_ui/modules/{feature}/`
- Read the fixture in `tests/new_ui/fixtures/{feature}/`
- Search for related tests that may share the same issue

### Step 4: Apply Fixes

Based on root cause classification, apply targeted fixes. See TEMPLATES.md for
common fix patterns.

### Step 5: Run Locally

```bash
# Set environment
export ENV=staging  # or prod, dev

# Run specific test
npx playwright test tests/new_ui/tests/notifications/QA-79266-create-channel-using-email.spec.ts --headed --timeout=120000

# Run by pattern
npx playwright test --grep "QA-79266" --headed --timeout=120000

# Run with specific project
npx playwright test --project=new_ui_notifications --headed
```

### Step 6: Iterate

If the test still fails:

1. Read the new error message
2. Re-classify the failure
3. Apply additional fix
4. Re-run locally
5. Maximum 5 iterations per test

## Parallel Fixing Strategy

When multiple tests fail:

1. **Parse all failures** from the CI log
2. **Group by root cause** — tests failing for the same reason may share a fix
3. **Launch up to 4 parallel agents** — each agent handles one test
4. **Each agent follows the full fix cycle**: investigate -> fix -> verify
5. **Shared fixes propagate** — if Agent 1 fixes a shared module, Agent 2 benefits

## Critical Requirements

1. **Do not modify test intent** — fix the implementation, not what the test validates
2. **Follow existing patterns** — match the style of surrounding code
3. **Use step() function** with BDD-style descriptions ("Given", "When", "Then")
4. **Use @utils alias** for tag imports: `import { TAG } from '@utils';`
5. **Use console.log** or `debugLog` for logging (no custom logger framework)
6. **Preserve 3-tier pattern** — locators, methods, module classes
7. **Include appropriate tags** — e.g., `tag: [TAG.prod, TAG.smoke]`
8. **One test per file** — never merge tests
9. **Maximum 5 iterations per test** — stop and report if not fixable

## Output Format

### Success

```
Test Fix Complete

File: tests/new_ui/tests/{feature}/QA-{ID}_description.spec.ts
Environment: staging
Root Cause: LOCATOR

Changes Made:
  - tests/new_ui/modules/{feature}/{feature}_locators.ts: Updated selector for addChannelBtn
  - tests/new_ui/tests/{feature}/QA-{ID}_description.spec.ts: Added waitFor before click

Verification:
  - Local Run: PASS
  - Iterations: 2 of 5

Next Steps:
  1. Review changes
  2. Run full test suite: npx playwright test --project=new_ui_{feature}
  3. Push and verify in CI
```

### Incomplete

```
Test Fix Incomplete

File: tests/new_ui/tests/{feature}/QA-{ID}_description.spec.ts
Iterations: 5 of 5 (max reached)
Last Error: {error message}

Investigation Summary:
  - Root cause: {classification}
  - Fixes attempted: {list}
  - Current state: {what works, what doesn't}

Manual Investigation Needed:
  - {specific area to investigate}
  - {suggested next steps}
```

## Error Handling

If test file not found:

- Verify file path from CI log
- Search for the test by ID: `Grep: QA-{ID} in tests/`

If module not found:

- Search existing modules: `Glob: tests/new_ui/modules/**/*_module.ts`
- Check if the module was recently renamed or moved

If local environment differs from CI:

- Verify `ENV` environment variable is set correctly
- Check `config/.env.{ENV}` file has correct settings
- Compare local app version with CI version

## Browser Automation Tools

When visual inspection of the live application is needed:

1. **`playwright-cli` (preferred)** — Fast CLI-based browser automation. Use for
   login, navigation, snapshots, and element inspection. Invoked via Bash:

   ```bash
   playwright-cli open {url}
   playwright-cli snapshot
   playwright-cli eval "document.querySelectorAll('button').length"
   playwright-cli close
   ```

2. **Playwright MCP (fallback)** — Use when `playwright-cli` is insufficient
   (e.g., complex element ref interactions, drag-and-drop inspection, or when
   you need `browser_evaluate` with element refs from a snapshot).

## Related Skills

- `playwright-cli` — Primary tool for live page exploration and locator discovery
- `mcp-page-explorer` — MCP-based page exploration (fallback for advanced scenarios)
