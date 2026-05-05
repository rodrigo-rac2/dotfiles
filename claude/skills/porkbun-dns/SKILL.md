---
name: porkbun-dns
description: Manage DNS records on Porkbun-registered domains via the Porkbun JSON API. Use when the user needs to add/list/delete DNS records on a Porkbun domain, set up Google Workspace email DNS (TXT verification, MX records), prepare a test domain for an integration (Google, Cisco Duo, M365), or troubleshoot Porkbun API access. Triggers on "porkbun", "rodrigo-qatest.xyz", "google workspace dns", or "add MX/TXT record".
allowed-tools: Bash, Read, Write
---

# Porkbun DNS Management

Manages DNS records on Porkbun via their JSON API. Primary use case: configuring DNS for the QA test domain `rodrigo-qatest.xyz` for Google Workspace and other integration tests.

## Prerequisites (one-time setup per machine)

1. **Generate API key + secret** at https://porkbun.com/account/api
2. **Enable API access for the specific domain** at https://porkbun.com/account/domainsSpeedy — find the domain row, click DETAILS, toggle "API ACCESS" ON. This is OFF by default for security and is the #1 reason API calls fail.
3. **Save credentials** at `~/.config/porkbun/credentials`:
   ```bash
   mkdir -p ~/.config/porkbun
   cat > ~/.config/porkbun/credentials <<'EOF'
   export PORKBUN_API_KEY="pk1_..."
   export PORKBUN_SECRET_KEY="sk1_..."
   EOF
   chmod 600 ~/.config/porkbun/credentials
   ```

## CLI

The skill ships `scripts/porkbun-dns`. Add it to PATH or call directly:
```bash
~/.claude/skills/porkbun-dns/scripts/porkbun-dns <command> [args...]
```

| Command | Purpose |
|---|---|
| `ping` | Verify auth, returns your public IP |
| `list <domain>` | Show all records on the domain |
| `add <domain> <type> <name> <content> [ttl]` | Add any record (`name=""` for apex) |
| `delete <domain> <record-id>` | Delete by record ID (get ID from `list`) |
| `google-verify <domain> <token>` | Add Google site verification TXT (token only, no prefix) |
| `google-mx <domain>` | Add Google Workspace MX (smtp.google.com, prio 1) |

## Google Workspace setup flow

When onboarding a domain to Google Workspace, the typical sequence is:

1. **Domain verification** — Google generates a token like `abc123def456...` and asks you to add it as a TXT record on the apex. The Workspace UI shows the value as `google-site-verification=abc123def456...`. Pass *only* the token (after the `=`) to the skill — it adds the prefix automatically:
   ```bash
   porkbun-dns google-verify rodrigo-qatest.xyz <token-from-google>
   ```
   Then click "Verify" in the Workspace setup. Propagation is typically <1 minute on Porkbun.

2. **MX records for Gmail** — once verified, Google asks you to set MX records. Modern Google Workspace (2023+) uses a single MX record: `smtp.google.com` priority 1. The skill adds it directly:
   ```bash
   porkbun-dns google-mx rodrigo-qatest.xyz
   ```

3. **Optional but recommended for production-like testing** — SPF, DKIM, DMARC. For a short-lived QA tenant on a 14-day trial, these are usually skippable. Add only if your test specifically validates email auth.

## Common gotchas

- **"API access not enabled"** — the most common error. The API toggle is per-domain and OFF by default. Step 2 in setup above.
- **Apex records** — Porkbun expects `name=""` (empty string) for the apex (`rodrigo-qatest.xyz` itself), not `@`. The CLI passes empty string correctly.
- **TTL** — minimum 600 seconds. Defaults to 600 in the CLI; use 3600 for stable records (MX).
- **Multiple TXT records on apex** — fine, they coexist. Don't delete the Google verification TXT after verification — Google may re-check it.

## Reference

- Porkbun API docs: https://porkbun.com/api/json/v3/documentation
- Google Workspace MX setup: https://support.google.com/a/answer/140034
