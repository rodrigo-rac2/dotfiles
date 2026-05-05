---
name: mcp-page-explorer-compassone
description:
  Uses Playwright MCP for browser automation to login, explore pages, and
  generate locators and page modules. Ideal for creating new module files
  by visually inspecting the live CompassOne application. Supports user-driven
  exploration with DOM analysis and generates code following the project's
  3-tier module pattern (locators, methods, module).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
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

# MCP Page Explorer - Locator & Module Generator

Explore CompassOne pages using Playwright MCP browser automation to generate
locators and page modules following the CompassOneQA 3-tier pattern.

## What This Skill Does

1. **MCP Authentication**: Logs into the CompassOne application using configured
   credentials
2. **Page Navigation**: Navigates to the target page through the application UI
3. **DOM Analysis**: Inspects the live DOM structure to identify elements
4. **Locator Generation**: Creates locator classes using Playwright's native API
5. **Module Generation**: Creates the full 3-tier module structure (locators,
   methods, module)
6. **Validation**: Validates generated locators against the live DOM

## How to Use

### Quick Start

```
> Explore the Notifications page and generate locators
> Login to staging and navigate to Asset Inventory page
> Generate page module for the Cloud Posture Baselines modal
```

### With Options

```
> Explore Settings > Integrations page and create locators
> Navigate to MAC Policies and validate existing locators
> Generate module for Vulnerabilities list with filtering support
```

## Prerequisites

### Environment Setup

```bash
# Set environment
export ENV=staging

# Verify MCP auth config
npx ts-node .claude/mcp-auth.ts
```

### Required Credentials

Environment files must be configured in `config/` directory:

- `config/.env.{environment}` - Environment-specific (C1_ENVIRONMENT, etc.)
- `config/.env` - Sensitive credentials (C1_EMAIL, C1_PASSWORD, C1_MFA_SECRET)

## CompassOneQA Module Pattern

### Output Files

```
tests/new_ui/modules/{feature}/
  {feature}_locators.ts   # Locator class with getter methods
  {feature}_methods.ts    # Methods class extending locators
  {feature}_module.ts     # Module class aggregating both
```

### 3-Tier Pattern

```typescript
// 1. Locators ({feature}_locators.ts)
export class FeatureLocators {
  readonly page: Page;
  constructor(page: Page) {
    this.page = page;
  }

  // Locator getter methods
  addButton(): Locator {
    return this.page.getByRole('button', { name: 'Add' });
  }
}

// 2. Methods ({feature}_methods.ts)
export class FeatureMethods extends FeatureLocators {
  // Action methods using locator getters
  async clickAddButton(): Promise<void> {
    await this.addButton().waitFor({ state: 'visible' });
    await this.addButton().click();
  }
}

// 3. Module ({feature}_module.ts)
export class FeatureMdl {
  readonly locators: FeatureLocators;
  readonly methods: FeatureMethods;
  constructor(page: Page) {
    this.locators = new FeatureLocators(page);
    this.methods = new FeatureMethods(page);
  }
}
```

## Workflow Overview

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   1. LOGIN   │───►│  2. NAVIGATE │───►│  3. EXPLORE  │
│  MCP Auth    │    │  User-driven │    │  DOM Analysis│
└──────────────┘    └──────────────┘    └──────────────┘
                                               │
       ┌───────────────────────────────────────┘
       ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ 4. GENERATE  │───►│  5. GENERATE │───►│ 6. VALIDATE  │
│   Locators   │    │    Module    │    │  Live DOM    │
└──────────────┘    └──────────────┘    └──────────────┘
```

## Step 1: Authentication

### Get Auth Configuration

```typescript
import { getMcpAuthConfig, getMcpAuthCredentials } from './.claude/mcp-auth';

const config = getMcpAuthConfig('default');
// Returns: { environment, baseUrl, userType, loginUrl, ... }

const creds = getMcpAuthCredentials('default');
// Returns: { username, password, mfaSecret }
```

### Login Flow

1. Navigate to `config.loginUrl` (includes SSO bypass if needed)
2. Enter email in email input
3. Click Next button
4. Enter password in password input
5. Click Next button
6. Enter TOTP code in MFA input
7. Click Continue button
8. Wait for `[role="combobox"]` to confirm login success

### Supported User Types

- `default` - Standard test user (C1_EMAIL, C1_PASSWORD, C1_MFA_SECRET)
- `account-admin` - Account Admin (C1_EMAIL_AA, etc.)
- `customer-admin` - Customer Admin (C1_EMAIL_CA, etc.)
- `blackpoint-admin` - Blackpoint Admin (C1_EMAIL_BA, etc.)
- And more (see `.claude/mcp-auth.ts`)

## Step 2: Page Navigation

Navigate through the application UI to reach the target page.

### Common Navigation Patterns

**Using GlobalCommons patterns:**

```javascript
// Select account/tenant via combobox
await browser_click({ element: 'Account selector combobox' });
await browser_type({ element: 'Search tenant input', text: 'BPC AUTOMATION' });
await browser_click({ element: 'Tenant option' });

// Click sidebar menu
await browser_click({ element: 'Notifications menu item' });
```

## Step 3: DOM Analysis

Use JavaScript evaluation to analyze the page structure:

```javascript
await browser_evaluate({
  expression: `
    Array.from(document.querySelectorAll('button, input, [role], [data-testid]'))
      .map(el => ({
        tag: el.tagName,
        role: el.getAttribute('role'),
        ariaLabel: el.getAttribute('aria-label'),
        testId: el.getAttribute('data-testid'),
        text: el.textContent?.trim().substring(0, 50),
        placeholder: el.placeholder,
      }))
  `,
});
```

### Analysis Priorities

1. **Role attributes**: `role`, `aria-label`, `aria-labelledby`
2. **Test IDs**: `data-testid`
3. **Semantic HTML**: `<button>`, `<nav>`, `<table>`, `<form>`
4. **Placeholders**: For input elements
5. **Text content**: Visible labels

## Step 4: Generate Locators

Create locator class following CompassOneQA patterns:

```typescript
// tests/new_ui/modules/{feature}/{feature}_locators.ts

import { Page, Locator } from 'playwright';

export class FeatureLocators {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  // Use Playwright's getByRole (preferred)
  addButton(): Locator {
    return this.page.getByRole('button', { name: 'Add' });
  }

  // Use getByTestId when available
  tableBody(): Locator {
    return this.page.getByTestId('ui/table/table-body');
  }

  // Use getByPlaceholder for inputs
  searchInput(): Locator {
    return this.page.getByPlaceholder('Search...');
  }

  // Use getByRole with filter for complex elements
  channelRow(channelName: string): Locator {
    return this.page.getByRole('row', { name: channelName });
  }

  // Use .first() when multiple elements match
  firstCombobox(): Locator {
    return this.page.getByRole('combobox').first();
  }
}
```

### Locator Priority Order (MUST FOLLOW)

1. `getByRole` with name - Most stable, accessibility-focused
2. `getByTestId` - Stable if data-testid exists
3. `getByLabel` - Good for form fields
4. `getByPlaceholder` - For inputs with placeholder
5. `getByText` - Visible text content
6. `locator()` with CSS - Last resort

## Step 5: Generate Module

Create the full 3-tier module structure:

### Locators File

```typescript
// {feature}_locators.ts
import { Page, Locator } from 'playwright';

export class FeatureLocators {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  // Locator getter methods...
}
```

### Methods File

```typescript
// {feature}_methods.ts
import { Page, expect } from '@playwright/test';
import { FeatureLocators } from './{feature}_locators';

export class FeatureMethods extends FeatureLocators {
  constructor(page: Page) {
    super(page);
  }

  async navigateToFeature(): Promise<void> {
    // Navigation implementation
  }

  async performAction(): Promise<void> {
    // Action implementation using locator getters
    await this.addButton().waitFor({ state: 'visible' });
    await this.addButton().click();
  }
}
```

### Module File

```typescript
// {feature}_module.ts
import { Page } from 'playwright';
import { FeatureLocators } from './{feature}_locators';
import { FeatureMethods } from './{feature}_methods';

export class FeatureMdl {
  readonly page: Page;
  readonly locators: FeatureLocators;
  readonly methods: FeatureMethods;

  constructor(page: Page) {
    this.page = page;
    this.locators = new FeatureLocators(page);
    this.methods = new FeatureMethods(page);
  }
}
```

## Step 6: Validate Locators

Test each locator against the live DOM:

```javascript
await browser_evaluate({
  expression: `
    const results = {};

    // Test getByRole('button', { name: 'Add' })
    results['addButton'] = document.querySelector('[role="button"]')?.textContent?.includes('Add');

    // Test getByTestId('ui/table/table-body')
    results['tableBody'] = document.querySelector('[data-testid="ui/table/table-body"]') !== null;

    return results;
  `,
});
```

## Fixture Integration

When adding a new module, also create the fixture:

```typescript
// tests/new_ui/fixtures/{feature}/{feature}_fixtures.ts

import { commonFixture } from '../commons/common_fixtures';
import { FeatureMdl } from '../../modules/{feature}/{feature}_module';

export const featureTests = commonFixture.extend<{
  FeaturePage: FeatureMdl;
}>({
  FeaturePage: async ({ page }, use) => {
    const FeaturePage = new FeatureMdl(page);
    use(FeaturePage);
  },
});
```

## Best Practices

### DO

- Use `getByRole` when possible - it's the most stable
- Use `.first()` or `.nth()` when multiple elements match
- Group related locators logically in the class
- Add JSDoc comments for complex locators
- Test locators against the live DOM before finalizing

### DON'T

- Use fragile CSS selectors like `div > div > div`
- Rely on dynamic class names
- Use index-based selectors without context
- Mix locators with business logic (keep them in methods)
- Use XPath (Playwright's API is more readable)

## Error Handling

### Login Failures

- Verify `ENV` environment variable is set
- Check credentials in `config/.env.{ENV}` and `config/.env`
- Ensure MCP Playwright extension is running

### Navigation Failures

- Wait for page load indicators
- Check for modal dialogs blocking interaction
- Verify element is visible before clicking

### Locator Validation Failures

- Check element exists in current DOM state
- Verify selector syntax
- Use browser DevTools to test selectors

## Session Management

### Start Session

```
> Login to staging and explore Notifications page
```

### Continue Session

```
> Navigate to the Channels section
> Analyze the table structure
```

### End Session

```
> Generate the module files
> Close the browser session
```

## Related Skills

- `fix-flaky-tests` — Fix failing tests by updating locators
