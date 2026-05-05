---
name: setup-google-workspace-tenant
description: Runbook to provision a new Google Workspace trial tenant for QA testing on a custom domain. Use when the user needs a fresh Workspace environment (e.g., for testing a new Google connector or starting a parallel test tenant), or when rebuilding the rodrigo-qatest.xyz tenant from scratch.
allowed-tools: Bash, Read, Write, WebFetch
---

# Set up a Google Workspace QA Tenant

Provisions a new Google Workspace trial tenant on a domain you control, ready for integration testing. Trial is **14 days, 10 users max, USD billing $7-17/user/mo after**.

**Prerequisite:** A domain you control with **DNS API access**. If you don't have one yet, run the `setup-test-domain-porkbun` skill first.

## Step 1 — Choose plan and country

| Plan | Cost | Features needed for QA |
|---|---|---|
| **Business Starter** | $7/user/mo | Sufficient for most tests (custom email, admin console, all directory APIs) |
| Business Standard | ~$17/user/mo | Only if test specifically needs Drive shared spaces, advanced Meet, etc. |

**Country/billing:** PICK CAREFULLY — you cannot easily change country mid-signup, and country forces billing currency. If unsure, start with Brazil/your actual country (BRL) for simplicity. United States works too (USD) if you have a US address available.

## Step 2 — Start the trial (manual, browser)

Open https://workspace.google.com/business/signup/welcome

Walk through:

| Field | Value |
|---|---|
| Business name | Anything descriptive (e.g., "Rodrigo QA Test") |
| Number of employees | **Just you** — keeps trial scope small |
| Country | See Step 1 |
| First/Last name | Real name |
| Current email | Personal email (for trial communications) |
| Domain choice | "Yes, I have one I can use" → enter your domain |

## Step 3 — Create admin user

| Field | Value |
|---|---|
| Username | `admin` (becomes `admin@<your-domain>`) |
| Password | Strong, save in password manager |

This is your Workspace **super-admin** — needed for everything that follows.

## Step 4 — Payment + contact info

- **Payment** is required upfront but **not charged for 14 days** — set a reminder if you don't want to keep it
- **Contact info:** must match your billing country (US country forces US address; Brazil country accepts BR address)
- **If country mismatch with your actual location:** you have two paths:
  1. Cancel signup, restart with correct country
  2. Use a legitimate address in the chosen country (Blackpoint HQ if BP-related, friend/family otherwise — never invent fake info)

After "Concordar e iniciar o teste", Google logs you in as the new admin.

## Step 5 — Verify domain ownership (DNS TXT)

Google's setup wizard asks you to add a TXT record. The token looks like:
```
google-site-verification=<long-token>
```

**If using porkbun-dns skill:**
```bash
~/.claude/skills/porkbun-dns/scripts/porkbun-dns google-verify <your-domain> <token-only>
```
Pass *only* the token (the part after `=`). The skill prefixes `google-site-verification=` automatically.

Wait ~30 seconds, then click **Verify** in Google's UI. Should pass instantly.

## Step 6 — MX records (optional for most QA)

If your test needs functional Gmail on the domain, add MX records:
```bash
~/.claude/skills/porkbun-dns/scripts/porkbun-dns google-mx <your-domain>
```

If your test only needs OAuth/directory APIs (most CompassOne Google connector tests), **skip this** — domain verification alone is enough.

## Step 7 — Get to the admin console

After verification, Google's setup wizard pushes "Ativar o Gmail" with no skip option. **Just navigate directly to https://admin.google.com** — that bypasses the wizard. Domain is verified, you're in.

## Step 8 — Create test users

In admin console:
1. **Directory → Users → Add new user**
2. Set first/last name and a username (e.g., `testuser1`)
3. Pick a password — save it; you'll need to log in as this user later

Or, after running `setup-gam7`, via CLI:
```bash
~/bin/gam7/gam create user testuser1@<your-domain> firstname Test lastname User1 password "ChangeMe!2026" changepassword off
```

## Trial → Paid transition

- **14 days exactly** from signup; check the "Faturamento" card in admin console for the cutover date
- After the 14th day, your card is auto-charged for the chosen plan
- If you forget and let it lapse with no billing, the tenant **suspends** — you'll need to re-enter payment info to revive it
- **Set a reminder** ~2 days before to decide: keep paying ($7-17/mo) or cancel

## When you'd want to redo this

- Trial expired and you don't want to pay
- Want to test on a fresh tenant with no prior state (e.g., after a connector test left junk users/groups)
- Testing multi-tenant scenarios that need a second Workspace
- Original tenant got into a weird state from earlier testing

In any of those cases, you can register a *new* test domain (`setup-test-domain-porkbun`) and run this skill again — total time ~30 minutes.

## Common gotchas

- **Country picker locked after a certain point** — if you advance past Step 4 with the wrong country, you generally can't back up. Cancel and restart.
- **Brazilian card cross-border** — some BR cards don't accept USD merchant billing. Test the card early (Step 4) before completing the rest.
- **Stuck on "Ativar Gmail"** with no skip — bypass via direct admin.google.com URL (Step 7).
- **TXT record propagation** — usually <30s on Porkbun; if Google says "not found" wait a minute and retry. `dig +short TXT <domain> @8.8.8.8` confirms propagation.
- **Domain verification banner persists in admin console** even after success — harmless, can be dismissed or ignored.

## Reference

- Trial signup: https://workspace.google.com/business/signup/welcome
- Admin console: https://admin.google.com
- Workspace plans: https://workspace.google.com/pricing.html
