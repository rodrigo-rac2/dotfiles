---
name: setup-test-domain-porkbun
description: Runbook to register a new test domain on Porkbun and wire up DNS API access for automation. Use when the user needs a fresh throwaway domain for an integration test (Google Workspace, M365, Cisco Duo, or any TLD-control scenario), or when redoing the rodrigo-qatest.xyz setup from scratch on a different domain.
allowed-tools: Bash, Read, Write, WebFetch
---

# Set up a Test Domain on Porkbun (with API access)

End-to-end runbook to take a fresh throwaway domain from "doesn't exist yet" to "fully API-controllable for DNS automation." Cost is ~$2 first year for `.xyz` (~$13 renewal). Used as the foundation for any integration test that needs domain ownership (Google Workspace, M365, custom email, etc.).

## Why Porkbun

- Cheap: `.xyz` ~$2/year first year, ~$13 renewal — best balance of cheap-and-private
- Free WHOIS privacy by default (no need to turn on)
- Clean JSON API for DNS automation (`api.porkbun.com/api/json/v3/...`)
- No upsells in checkout
- **Caveat:** aggressive bot detection — registration must be done manually in your real browser, not via playwright-cli

## TLD trade-offs (decision shortcut)

| TLD | First yr | Renewal | WHOIS Privacy | Notes |
|---|---|---|---|---|
| `.xyz` | ~$2 | ~$13 | ✅ free | **Best default** — privacy + cheap renewal |
| `.us` | ~$2 | ~$7 | ❌ public (NTIA forbids) | Cheaper renewal but exposes personal info forever |
| `.online` | ~$2 | ~$29 | ✅ free | Renewal too expensive vs. .xyz |
| `.lol` | ~$2 | ~$26 | ✅ free | Renewal too expensive vs. .xyz |

**Default recommendation:** `.xyz` unless the user is clear they don't care about WHOIS privacy and renewal cost is the only factor.

## Step 1 — Register the domain (manual, in user's browser)

Porkbun blocks headless browsers entirely (returns "Hardcore hacker detected" on every page). Don't try to automate this — instruct the user to do it themselves:

1. Open https://porkbun.com/ in their normal browser (already-logged-in if they have an account)
2. Search for the desired name
3. Pick the cheapest acceptable TLD per the table above
4. Add to cart → checkout
5. Complete payment

After registration, the user lands on a "GREAT SUCCESS" page. They can click "Continue to Domain Management."

## Step 2 — Enable API access (manual, in user's browser)

API access is OFF by default per-domain (security). Without this, every API call returns:
> `Domain is not opted in to API access. You can enable API access for all domains globally from your account settings at porkbun.com.`

To enable:

1. Navigate to https://porkbun.com/account/domainsSpeedy
2. Find the new domain row → click **Details** dropdown
3. Toggle **API ACCESS** to **ON**

## Step 3 — Generate API keys (manual, in user's browser)

1. Navigate to https://porkbun.com/account/api
2. Click **Create API Key** (give it any name, e.g., `claude-1`)
3. Copy the **API Key** (`pk1_...`) and **Secret Key** (`sk1_...`)
4. **The secret is shown ONCE** — save immediately

## Step 4 — Save credentials locally

```bash
mkdir -p ~/.config/porkbun
cat > ~/.config/porkbun/credentials <<'EOF'
export PORKBUN_API_KEY="pk1_..."
export PORKBUN_SECRET_KEY="sk1_..."
EOF
chmod 600 ~/.config/porkbun/credentials
```

The `porkbun-dns` skill picks these up automatically from this path.

## Step 5 — Verify

```bash
~/.claude/skills/porkbun-dns/scripts/porkbun-dns ping
~/.claude/skills/porkbun-dns/scripts/porkbun-dns list <domain>
```

`ping` should return `"credentialsValid": true`. `list` should return the default Porkbun records (1 ALIAS + 1 wildcard CNAME pointing to `pixie.porkbun.com`, plus 4 NS records).

## Settings worth checking on the new domain

| Setting | Default | Recommendation |
|---|---|---|
| **API ACCESS** | OFF | **ON** (set in Step 2) |
| **AUTO RENEW** | ON | Leave ON if keeping for ongoing tests; OFF if one-shot |
| **DOMAIN LOCK** | ON | Leave ON (prevents unauthorized transfer) |
| **CONTACT PRIVACY** | ON (using privacy) | Leave ON |
| **PORKBUN DNSSEC** | OFF | Leave OFF — overkill for QA, complicates troubleshooting |

## Common gotchas

- **"Domain is not opted in to API access"** — Step 2 was skipped. Most common error.
- **Secret key lost** — generate a new key pair; the old one stays valid until manually revoked.
- **Bot detection on Porkbun UI** — never automate registration; always do it in the user's real browser.

## Reference

- Porkbun API docs: https://porkbun.com/api/json/v3/documentation
- Domain management portal: https://porkbun.com/account/domainsSpeedy
- API key portal: https://porkbun.com/account/api
