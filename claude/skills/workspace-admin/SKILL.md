---
name: workspace-admin
description: Manages Google Workspace users, groups, and directory state on the QA tenant rodrigo-qatest.xyz via GAM7. Use when the user needs to create/suspend/delete test users, manage group memberships, set up preconditions for CompassOne Google connector tests (C1-6993 and successors), or run any directory operation that would otherwise require clicking through admin.google.com. Triggers on "workspace user", "create test user", "suspend user", "rodrigo-qatest.xyz user", "google workspace test", or "GAM".
allowed-tools: Bash, Read, Write
---

# Google Workspace Admin (GAM7) — QA Tenant

Manages the persistent QA Google Workspace tenant `rodrigo-qatest.xyz` via [GAM7](https://github.com/GAM-team/GAM). Built for recurring CompassOne Google connector testing (started with C1-6993, will be reused for follow-up work).

## Tenant snapshot

| Field | Value |
|---|---|
| Primary domain | `rodrigo-qatest.xyz` |
| Customer ID | `C02fpnd78` |
| Super-admin | `admin@rodrigo-qatest.xyz` |
| GAM project | `gam-project-7oa8q` |
| GAM service account | `gam-project-7oa8q@gam-project-7oa8q.iam.gserviceaccount.com` |
| GAM client ID (DwD) | `102299417664369438551` |
| Trial → paid billing | starts 2026-05-15 (USD) |

## GAM binary

Installed at `~/bin/gam7/gam`. The `gam` alias is in `~/.zshrc` — works in any new shell. To use without `.zshrc`, call `~/bin/gam7/gam` directly.

## Quick reference — operations needed for CompassOne QA

### Users (the most common ops)

```bash
# Create a test user
gam create user testuser1@rodrigo-qatest.xyz \
    firstname Test lastname User1 \
    password "ChangeMeNow!2026" changepassword off

# Suspend a user (this is what CompassOne "disable from SNAP" does under the hood)
gam update user testuser1@rodrigo-qatest.xyz suspended on

# Unsuspend
gam update user testuser1@rodrigo-qatest.xyz suspended off

# Verify suspension status
gam info user testuser1@rodrigo-qatest.xyz | grep -i suspend

# Delete a user (cleanup after test)
gam delete user testuser1@rodrigo-qatest.xyz

# List all users in the tenant
gam print users
```

### Verification helpers

```bash
gam info domain                 # confirms tenant + scopes still working
gam print users                 # all users; useful before/after onboarding tests
gam info user <email>           # full attributes (suspended, lastLoginTime, etc.)
gam user <email> check serviceaccount   # re-verify DwD scopes if anything breaks
```

### Bulk reset between test cycles

```bash
# Delete all non-admin test users
gam print users query "isAdmin=false" | tail -n +2 | while read -r email; do
    gam delete user "$email"
done
```

## CompassOne C1-6993 test recipe

Per Erik Witkowski's test plan (Jira comment 2026-04-30):

1. **Setup** — ensure at least one test user exists:
   ```bash
   gam create user testuser1@rodrigo-qatest.xyz firstname Test lastname User1 password "ChangeMe!2026" changepassword off
   ```
2. **Onboard** the Google Workspace connection in CompassOne with the new flag enabled. Confirm onboarding succeeds without provisioning a new GCP project.
3. **Test enable/disable from SNAP:**
   - In CompassOne, disable `testuser1@rodrigo-qatest.xyz`
   - Verify via GAM: `gam info user testuser1@rodrigo-qatest.xyz | grep -i suspend` — should show `Suspended: True`
   - In CompassOne, enable the user
   - Verify: `Suspended: False`
4. **Test login detection from unapproved country:**
   - Use a VPN to set source country outside the approved list
   - Sign in to https://accounts.google.com as `testuser1@rodrigo-qatest.xyz`
   - Confirm CompassOne raises the detection
5. **Test two connections, offboard one:**
   - Onboard a second connection (could be a different OU or same domain second linkage if supported)
   - Offboard one — credentials should NOT be deleted (per ticket)
   - Verify the other connection still works
6. **Test flag off:** Switch the feature flag off, confirm legacy onboarding flow still works (provisions per-customer GCP project)
7. **Cleanup:**
   ```bash
   gam delete user testuser1@rodrigo-qatest.xyz
   ```

## When GAM stops working

Most likely causes after time passes:

- **Service account key rotated/expired** → `gam rotate sakey` (or `gam upload sakey` if it lost the key)
- **DwD scopes were modified by a Workspace admin** → re-run `gam user admin@rodrigo-qatest.xyz check serviceaccount`, follow the URL to re-authorize
- **Trial expired without billing** → tenant suspended, set up billing before doing anything else (see `google_workspace_qa.md` memory)
- **OAuth token expired** → `gam oauth create` to refresh `~/.gam/oauth2.txt`

## Don't

- Don't delete `admin@rodrigo-qatest.xyz` — it's the only super-admin and the GAM admin user. Losing it means rebuilding from scratch.
- Don't disable API access on the GAM project in admin.google.com → API Controls. That breaks GAM auth.
- Don't re-enable the `iam.disableServiceAccountKeyUpload` org policy without re-uploading a fresh key first.
