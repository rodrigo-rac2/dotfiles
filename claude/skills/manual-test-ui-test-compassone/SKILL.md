---
name: manual-test-ui-test-compassone
description:
  Navigates to the CompassOne application (staging or prod) and performs
  manual-style UI tests using playwright-cli (primary) or Playwright MCP
  (fallback). Supports all user roles (BSA, BA, BU, AA, AU, CA, CU) with
  automatic TOTP/MFA generation. Use when you need to manually verify a feature,
  reproduce a bug, or explore the UI as a specific role.
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
  - mcp__playwright__browser_hover
  - mcp__playwright__browser_drag
  - mcp__playwright__browser_console_messages
  - mcp__playwright__browser_network_requests
  - mcp__playwright__browser_handle_dialog
  - mcp__playwright__browser_close
  - mcp__playwright__browser_resize
---

# Manual UI Test - CompassOne Browser Automation

Perform manual-style UI tests against the CompassOne application using
browser automation. Supports multi-role login, account/tenant navigation,
and all major UI areas.

## What This Skill Does

1. **Login**: Authenticates to CompassOne with the appropriate user role and
   generates the TOTP code automatically
2. **Navigate**: Selects account/tenant and navigates to the target feature
3. **Interact**: Performs clicks, form fills, and assertions as a human tester would
4. **Report**: Describes what was observed at each step
5. **Switch Roles**: Can re-login as a different role mid-session if needed

## How to Use

```
> Login to staging as Account Admin and check the billing page
> Go to prod as Customer User and verify the dashboard loads
> Navigate to Asset Inventory and look for devices named "TestDevice"
> Test the login flow as Blackpoint Admin on staging
> Manually verify that QA-326893 steps work as Customer User
```

## Environment Setup

```bash
# Set environment (default: staging)
export ENV=staging   # or prod

# Credentials live in config/.env (already populated)
# Environment URLs live in config/.env.staging / config/.env.prod
```

## Environments

| ENV     | C1_ENVIRONMENT (UI)                              |
| ------- | ------------------------------------------------ |
| staging | https://compassone.staging.snap.bpcybercloud.com |
| prod    | https://compassone.blackpointcyber.com           |

## User Roles & Credentials

All credentials are in `config/.env`. The `mcp-auth.ts` module maps user types
to their env var suffixes automatically.

| Role                   | Env Suffix | Email (qaautomatedusersa aliases)        |
| ---------------------- | ---------- | ---------------------------------------- |
| Blackpoint Super Admin | `_BSA`     | qaautomatedusersa@blackpointcyber.com    |
| Blackpoint Admin       | `_BA`      | qaautomatedusersa+ba@blackpointcyber.com |
| Blackpoint User        | `_BU`      | qaautomatedusersa+bu@blackpointcyber.com |
| Account Admin          | `_AA`      | qaautomatedusersa+aa@blackpointcyber.com |
| Account User           | `_AU`      | qaautomatedusersa+au@blackpointcyber.com |
| Customer Admin         | `_CA`      | qaautomatedusersa+ca@blackpointcyber.com |
| Customer User          | `_CU`      | qaautomatedusersa+cu@blackpointcyber.com |

**Alternate Gmail accounts** (for stricter RBAC isolation, NOCHANGES accounts):

- `ACCOUNT_ADMIN_EMAIL` / `ACCOUNT_ADMIN_PASSWORD` / `ACCOUNT_ADMIN_MFA_SECRET`
- `CUSTOMER_ADMIN_EMAIL` / `CUSTOMER_ADMIN_PASSWORD` / `CUSTOMER_ADMIN_MFA_SECRET`
- `CUSTOMER_USER_EMAIL` / `CUSTOMER_USER_PASSWORD` / `CUSTOMER_USER_MFA_SECRET`
- `ACCOUNT_USER_EMAIL` / `ACCOUNT_USER_PASSWORD` / `ACCOUNT_USER_MFA_SECRET`
- `ACCOUNT_ADMIN_NOBILLING_EMAIL` (no billing access variant)
- `ACCOUNT_USER_NOBILLING_EMAIL` (no billing access variant)

**BPC Super Admin** (alternate primary from 1Password QA Secrets):

- `BPC_EMAIL` / `BPC_PASSWORD` / `BPC_MFA_SECRET`

## Step 1: Get Credentials

Before logging in, load credentials from the env file:

```bash
# Read credentials for the desired role
node -e "
require('dotenv').config({ path: 'config/.env.staging' });
require('dotenv').config({ path: 'config/.env' });

const role = process.argv[1] || '';
const suffix = { 'bsa': '_BSA', 'ba': '_BA', 'bu': '_BU', 'aa': '_AA', 'au': '_AU', 'ca': '_CA', 'cu': '_CU' }[role] || '';

console.log('EMAIL:', process.env['C1_EMAIL' + suffix] || process.env.C1_EMAIL);
console.log('PASSWORD:', process.env['C1_PASSWORD' + suffix] || process.env.C1_PASSWORD);
console.log('MFA_SECRET:', process.env['C1_MFA_SECRET' + suffix] || process.env.C1_MFA_SECRET);
console.log('BASE_URL:', process.env.C1_ENVIRONMENT);
" -- aa
```

## Step 2: Generate TOTP Code

TOTP codes expire every 30 seconds. Generate one immediately before entering it:

```bash
# Generate TOTP for a given secret (replace SECRET with actual value)
node -e "
const crypto = require('crypto');
const secret = 'BASE32SECRET';

// Base32 decode
const base32chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const clean = secret.toUpperCase().replace(/=+$/, '');
let bits = '';
for (const c of clean) {
  const idx = base32chars.indexOf(c);
  if (idx < 0) continue;
  bits += idx.toString(2).padStart(5, '0');
}
const bytes = Buffer.alloc(Math.floor(bits.length / 8));
for (let i = 0; i < bytes.length; i++) {
  bytes[i] = parseInt(bits.slice(i * 8, i * 8 + 8), 2);
}

// HOTP
const counter = Math.floor(Date.now() / 30000);
const buf = Buffer.alloc(8);
buf.writeBigInt64BE(BigInt(counter));
const hmac = crypto.createHmac('sha1', bytes).update(buf).digest();
const offset = hmac[hmac.length - 1] & 0x0f;
const code = ((hmac[offset] & 0x7f) << 24 | hmac[offset+1] << 16 | hmac[offset+2] << 8 | hmac[offset+3]) % 1000000;
console.log(String(code).padStart(6, '0'));
"
```

**Preferred (uses the project's otpauth library):**

```bash
node -e "
const OTPAuth = require('otpauth');
const secret = process.env.C1_MFA_SECRET || 'YOUR_SECRET_HERE';
const totp = new OTPAuth.TOTP({ digits: 6, issuer: 'bpsnap', period: 30, secret: OTPAuth.Secret.fromBase32(secret), algorithm: 'SHA1' });
console.log(totp.generate());
"
```

Or use the project's MFA module directly:

```bash
ENV=staging node -e "
require('dotenv').config({ path: 'config/.env.staging' });
require('dotenv').config({ path: 'config/.env' });
// Use ts-node for TypeScript
"
# Better: use ts-node
ENV=staging npx ts-node -e "
import * as OTPAuth from 'otpauth';
require('dotenv').config({ path: 'config/.env.staging' });
require('dotenv').config({ path: 'config/.env' });
const secret = process.env.C1_MFA_SECRET!;
const totp = new OTPAuth.TOTP({ digits: 6, issuer: 'bpsnap', period: 30, secret: OTPAuth.Secret.fromBase32(secret), algorithm: 'SHA1' });
console.log(totp.generate());
"
```

## Step 3: Login Flow

### SSO Bypass Rule

- Emails `@blackpointcyber.com` **without** `+` alias → use `?use-password-internal=true`
- Emails `@blackpointcyber.com` **with** `+` alias (e.g., `+ba`) → use standard URL
- Gmail accounts → use standard URL

### Login URL

```
# BSA (no +, needs bypass):
https://compassone.staging.snap.bpcybercloud.com/login?use-password-internal=true

# All others (+alias or gmail):
https://compassone.staging.snap.bpcybercloud.com
```

### Login Sequence (Playwright MCP)

```
1. browser_navigate to login URL
2. browser_snapshot → identify email input
3. browser_type: email input → enter email address
4. browser_click: "Log in to Blackpoint" button
5. browser_wait_for: password input visible
6. browser_type: password input → enter password
7. browser_click: "Continue" button
8. browser_wait_for: MFA code input (input[name="code"]) visible
9. [Generate TOTP code via bash command]
10. browser_type: MFA input → enter 6-digit code
11. browser_click: "Continue" button
12. browser_wait_for: [role="combobox"] visible → login confirmed
```

### Key Login Selectors

```
Email input:    input[type="email"][id="email"]  OR  input[name="email"]
Password input: input[type="password"][id="password"]
Next button:    button with text "Log in to Blackpoint"  OR  "Next"
MFA input:      input[name="code"]
Continue btn:   button[role="button"] with text "Continue"
Login success:  [role="combobox"]  (account/tenant selector)
```

## Step 4: Account & Tenant Selection

After login, you land on the dashboard. Most tests require selecting an account/tenant:

```
1. Click the [role="combobox"] (account selector, top of page)
2. Type a search term (e.g., "BPC AUTOMATION" or "QA Tenant")
3. Click the matching tenant/account option
4. Wait for the dashboard to reload with the selected context
```

### Common Test Accounts (from config/.env.staging)

- Use `process.env.TENANT_NAME` or `process.env.ACCOUNT_NAME` from the env file
- Blackpoint-level roles can see all tenants
- Account-level roles only see their assigned account
- Customer-level roles only see their assigned customer/tenant

## Step 5: Navigation Patterns

### Sidebar Navigation

```
Asset Inventory:  click link matching href*="asset-inventory" with text "Asset Inventory"
Notifications:    click link matching href*="notifications"
Policies:         click link matching href*="policies"
Cloud Posture:    click link matching href*="cloud-posture"
Integrations:     click link matching href*="integrations"
Discovery/Dashboard: click link matching href*="discovery" or brand logo
SIEM:             click link matching href*="siem"
```

### Direct URL Navigation (faster)

```
Asset Inventory: {C1_ENVIRONMENT}/msp/{accountId}/{tenantId}/asset-inventory
Notifications:   {C1_ENVIRONMENT}/msp/{accountId}/{tenantId}/notifications
Policies:        {C1_ENVIRONMENT}/msp/{accountId}/{tenantId}/policies
Cloud Posture:   {C1_ENVIRONMENT}/msp/{accountId}/{tenantId}/cloud-posture
```

Account and tenant IDs are in `config/.env.staging` / `config/.env.prod`.

## Common UI Patterns

### Tables

```javascript
// Row count
document.querySelectorAll('tbody [data-testid="ui/table/table-row"]').length;

// Find row by text
document
  .querySelectorAll('[data-testid="ui/table/table-cell"]')
  .find(el => el.textContent.includes('SearchText'));
```

Key test IDs:

- `[data-testid="ui/table/table-row"]` - Table rows
- `[data-testid="ui/table/table-cell"]` - Table cells
- `[data-testid="ui/table/table-body"]` - Table body
- `[data-testid="ui/table/table-header"]` - Column headers

### Modals / Drawers

```javascript
// Check if modal is open
document.querySelector('[role="dialog"]') !== null;

// Find modal title
document.querySelector('[role="dialog"] h1, [role="dialog"] h2')?.textContent;
```

### Comboboxes / Dropdowns

```javascript
// Find all comboboxes on page
document.querySelectorAll('[role="combobox"]').length;

// Get selected value
document.querySelector('[role="combobox"]')?.textContent;
```

### Buttons

```javascript
// Find button by text
Array.from(document.querySelectorAll('button')).find(
  b => b.textContent.trim() === 'Add Notification Channel',
);
```

### Toast Notifications

```javascript
// Check for success/error toast
document.querySelector('[role="alert"]')?.textContent;
```

## Page Structure Reference

### Discovery / Dashboard Page

- Account/Tenant combobox: `[role="combobox"]`
- User menu icon: button with user avatar (top right)
- Profile menu item: menu item with text "Profile"
- Role display: `input[type="text"]` showing role name in profile
- Sidebar nav links: `a[href*="{feature}"]`

### Asset Inventory Page

- URL pattern: `/asset-inventory`
- Device table rows: `tbody [data-testid="ui/table/table-row"]`
- Device name cell: `[data-testid="ui/table/table-cell"]` containing device name
- Filter/search input: `input[placeholder*="Search"]` or `input[placeholder*="Filter"]`
- Device detail panel: appears on row click (right side drawer)
- Export button: `button` with text "Export"
- Column headers: `[data-testid="ui/table/table-header"]`

### Notifications Page

- URL pattern: `/notifications`
- Add Channel button: `button` with text "Add Notification Channel"
- Channel table: standard table with `data-testid="ui/table/table-row"`
- Channel name cell: first cell in each row
- Edit/Delete actions: appear on row hover or in action column

### Global Notifications (Account-level, no tenant required)

Global notifications are configured at the account level and do **not** require selecting a tenant. Navigate directly:

```
{C1_ENVIRONMENT}/msp/{accountId}/notifications
```

- The "Notifications" link in the sidebar at account scope shows global notification rules
- Each rule has a toggle (enable/disable), name, event type, and channel
- Toggle state: `[role="switch"]` or `button[aria-checked]`
- Notification rule rows: standard `[data-testid="ui/table/table-row"]`
- To create: click "Add Notification" or equivalent CTA button
- Event type dropdown includes: `User Locked Out - Multiple Failed Logins` (CLOUD_RESPONSE_M365), etc.
- Scope options: Global (all tenants in account) vs. specific tenant
- **Note**: On staging, global M365 notifications may not deliver emails even when enabled (see C1-6574)

### Policies Page

- URL pattern: `/policies`
- Policy list: `[data-testid="ui/table/table-row"]`
- Create policy button: `button` with text "Create Policy" or "New Policy"

### Cloud Posture Page

- URL pattern: `/cloud-posture`
- Baseline table: standard table structure
- Status indicators: colored badges/chips

### Integrations Page

- URL pattern: `/integrations`
- Integration cards or table rows
- Connect/Disconnect buttons per integration

## Role Behavior Reference

| Feature         | BSA | BA  | BU  | AA  | AU  | CA  | CU  |
| --------------- | --- | --- | --- | --- | --- | --- | --- |
| All tenants     | ✓   | ✓   | ✓   | -   | -   | -   | -   |
| Account admin   | ✓   | ✓   | -   | ✓   | -   | -   | -   |
| Billing section | ✓   | ✓   | -   | ✓   | -   | -   | -   |
| Customer data   | ✓   | ✓   | ✓   | ✓   | ✓   | ✓   | ✓   |
| Edit settings   | ✓   | ✓   | -   | ✓   | -   | ✓   | -   |
| View only       | -   | -   | ✓   | -   | ✓   | -   | ✓   |

## Full Workflow Example

### Example: Verify Dashboard as Customer User

```
1. Read credentials:
   - Email: C1_EMAIL_CU from config/.env
   - Password: C1_PASSWORD_CU
   - MFA_SECRET: C1_MFA_SECRET_CU
   - URL: C1_ENVIRONMENT from config/.env.staging (has +cu so no SSO bypass)

2. Navigate: https://compassone.staging.snap.bpcybercloud.com

3. Login:
   - Fill email → click Next → fill password → click Continue
   - Generate TOTP from C1_MFA_SECRET_CU → fill code → click Continue
   - Wait for [role="combobox"]

4. Select tenant via combobox

5. Observe dashboard:
   - Take screenshot
   - Check sidebar nav items visible
   - Check user role in profile

6. Report: What was visible, what was accessible, any errors
```

### Example: Test Asset Inventory Table as Account Admin

```
1. Login as AA (C1_EMAIL_AA, C1_PASSWORD_AA, C1_MFA_SECRET_AA)
   URL: https://compassone.staging.snap.bpcybercloud.com (has +aa)

2. Select tenant via combobox

3. Navigate to Asset Inventory:
   - Click sidebar "Asset Inventory" link

4. Inspect table:
   - browser_evaluate: count rows → report count
   - browser_snapshot: capture current state
   - browser_click: first row → verify detail panel opens

5. Report observations
```

## Generating TOTP Quickly

When using Playwright MCP, generate the TOTP code via Bash before filling the MFA field:

```bash
# One-liner using node + otpauth (install once: npm install otpauth in project)
SECRET="MJWDEU3JKYWCUQSEHIWDAOSSJRXGGVZX" node -e "
const OTPAuth = require('./node_modules/otpauth');
const totp = new OTPAuth.TOTP({ digits: 6, period: 30, algorithm: 'SHA1', secret: OTPAuth.Secret.fromBase32(process.env.SECRET) });
console.log(totp.generate());
"
```

Or use the project's ts-node setup:

```bash
SECRET="MJWDEU3JKYWCUQSEHIWDAOSSJRXGGVZX" npx ts-node -e "
import * as OTPAuth from 'otpauth';
const s = process.env.SECRET!;
const totp = new OTPAuth.TOTP({ digits: 6, period: 30, algorithm: 'SHA1' as any, secret: OTPAuth.Secret.fromBase32(s) });
console.log(totp.generate());
"
```

## Running Existing Tests (Reference)

These commands run existing automated tests — useful to understand what tests exist:

```bash
# List all test files
find tests/new_ui/tests -name "*.spec.ts" | head -30

# Run a specific test
ENV=staging npx playwright test --grep "QA-326893" --project=new_ui_discovery --headed

# Run all RBAC tests
ENV=staging npx playwright test --project=new_ui_rbac --headed

# Run BVT tests
ENV=staging npx playwright test --grep "@bvt" --headed

# Run with debug mode
ENV=staging PWDEBUG=1 npx playwright test --grep "QA-210912" --headed
```

## Error Handling

### Login Fails at MFA Step

- TOTP codes expire in 30s — generate immediately before submitting
- Check system clock is accurate
- Try the debug approach: generate tokens for -30s, current, +30s windows

### Element Not Found

- Take a snapshot first to see current page state
- Check if a modal/dialog is blocking the element
- Verify the account/tenant is selected (some pages require it)
- Some elements only appear on hover — use `browser_hover` first

### Session Expired

- Auth state files in `.auth/` expire after 30 minutes
- Delete the auth file and re-login: `rm .auth/staging.user.json`

### Wrong Role Access

- Verify the correct env var suffix was used for credentials
- BSA/BA can see everything; CA/CU have most restrictions
- "NOCHANGES" Gmail accounts cannot make changes by design

## Critical Thinking & Exploratory Testing

**Do not only confirm the happy path.** After verifying the AC, actively look
for problems. Apply these lenses to every test:

### During Happy Path Testing

While confirming the expected behavior, passively collect signals:

- **Console errors**: run `playwright-cli console` after every page load and
  major interaction. JS errors are free bugs.
- **Network failures**: run `playwright-cli network` and look for 4xx/5xx
  responses that shouldn't be there.
- **Visual issues**: when taking screenshots, look for truncated text,
  misaligned elements, missing loading states.
- **Copy errors**: read all user-facing text. Typos, wrong labels, and
  misleading messages are real bugs.

### After Happy Path Passes

Once the AC is confirmed, you MUST ask the user:

> "Happy path confirmed. Want me to run a bug bash to explore alternative
> paths? I can estimate scenarios and time."

If the user agrees, invoke the `bug-bash-blackpoint` skill with the same
ticket. The bug-bash skill will:

1. Generate alternative test scenarios (RBAC, boundary, state, error handling, etc.)
2. Estimate effort for each
3. Ask the user for a time budget
4. Execute the selected scenarios
5. Report findings with evidence

If the user declines the bug bash, proceed with the QA stamp as normal.

### Minimum Critical Checks (always do these, even without a full bug bash)

Even if the user skips the full bug bash, always perform these quick checks
during your happy path testing (< 2 min total):

1. **Console check**: `playwright-cli console` on the page under test
2. **Wrong role quick check**: if the feature has RBAC implications, note which
   roles should NOT have access (don't test them unless asked, but flag it in
   your report)
3. **Refresh persistence**: after the key action, refresh the page and confirm
   the state stuck

## Related Skills

- `playwright-cli` — Fast CLI-based browser automation (preferred for speed)
- `mcp-page-explorer` — Generate locators and page modules from live DOM
- `fix-flaky-tests` — Fix failing automated tests
- `bug-bash-blackpoint` — Systematic exploratory testing beyond the happy path
