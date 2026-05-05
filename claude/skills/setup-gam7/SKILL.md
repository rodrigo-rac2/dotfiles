---
name: setup-gam7
description: Runbook to install GAM7 (Google Apps Manager) and fully configure it for a Workspace tenant — including the org-policy override that's required on new tenants. Use when the user needs CLI directory operations on a Workspace tenant for the first time, when GAM auth breaks and needs rebuilding, or when bootstrapping a second tenant.
allowed-tools: Bash, Read, Write, WebFetch
---

# Set up GAM7 for a Google Workspace Tenant

Installs GAM7 and walks through the full authentication chain (GCP project → OAuth client → service account → domain-wide delegation → org policy override). Total time ~15 minutes for a new tenant.

**Prerequisites:**
- Workspace tenant with super-admin access (run `setup-google-workspace-tenant` skill first)
- macOS (these instructions assume macOS — adjust for Linux/Windows as needed)

## Step 1 — Install GAM7

```bash
bash <(curl -s -S -L https://gam-shortn.appspot.com/gam-install) -l
```

The `-l` flag does limited install (binary only, no interactive setup). Adds the `gam` alias to `~/.zshrc` and `~/.profile`. Open a new shell to pick it up, or call `~/bin/gam7/gam` directly.

Verify:
```bash
~/bin/gam7/gam version | head -3
```

## Step 2 — Create the GCP project

```bash
gam create project
```

This is interactive — walks through:

1. **"It's important to mark the GAM Project Creation Client ID as trusted"** — opens browser tab to admin.google.com for trust step. Do it (Configure new app → search the client ID it gives you → mark Trusted). This step's client ID is `297408095146-fug707qsjv4ikron0hugpevbrjhkmsk7.apps.googleusercontent.com` (constant for all GAM users).
2. **Email prompt** — enter your Workspace super-admin (e.g., `admin@<domain>`)
3. **Browser auth flow** — log in as that admin, approve scopes
4. **Project ID prompt** — accept the auto-suggested ID (`gam-project-XXXXX`)
5. GAM enables 38 APIs. **Will fail at first** with `terms of service 'cloud' must be accepted` — this is normal. Visit https://console.developers.google.com/terms/cloud, accept ToS, return to terminal, press Enter. APIs will retry and succeed.

## Step 3 — Create OAuth client (interactive UI in GCP Console)

After APIs are enabled, GAM prints a URL like `https://console.cloud.google.com/auth/clients?project=gam-project-XXXXX&authuser=...`. The terminal lists 25+ steps.

**This part is automatable via playwright-cli (headed mode).** The flow:

1. Open the URL in `playwright-cli -s=gcp open <url> --headed`
2. User logs in manually (visible window)
3. Drive these clicks via playwright:
   - Dismiss free-trial banner ("Dispensar")
   - Click "Vamos começar" / "Get Started" if no "+ CREATE CLIENT" visible
   - Step 1 (App Information): App name `GAM`, support email = admin user → Avançar
   - Step 2 (Audience): select **Internal** → Avançar
   - Step 3 (Contact info): email = admin user → Avançar
   - Step 4 (Finish): tick "User Data Policy" checkbox → Continuar → Criar
   - Navigate to Clients page
   - Click **+ CREATE CLIENT**
   - Application type: **Desktop app**
   - Name: `GAM`
   - Click Create
4. Copy **Client ID** and **Client Secret** from the resulting dialog
5. Paste both into the GAM terminal prompt

## Step 4 — Trust the new GAM client (UI, automatable)

GAM next prints another URL for `https://admin.google.com/ac/owl/list?tab=configuredApps` and instructions to mark the new client as Trusted.

Drive via playwright (same `gcp` session):
1. Click "Configurar novo app" / "Configure new app"
2. Paste the new GAM Client ID, search, select GAM
3. Default scope (radio: "Todos em <org>") → Continuar
4. Select **Confiável** / **Trusted** → Continuar
5. Concluir

Return to terminal, press Enter.

## Step 5 — Service account key upload (the gotcha)

GAM next runs `gam upload sakey` automatically. **This will fail on most new Workspace tenants:**

```
Upload Failed: Constraint `constraints/iam.disableServiceAccountKeyUpload` violated
```

The org policy is enforced by default. Override it:

### 5a. Grant yourself OrgPolicy Admin

The Workspace super-admin doesn't auto-get this role. Find your org ID:
- Visit https://console.cloud.google.com/cloud-resource-manager
- Note the Organization ID for your domain (a numeric string)

Then in IAM at org level (`https://console.cloud.google.com/iam-admin/iam?organizationId=<ORG_ID>`):
1. Click **"Permitir acesso"** / **"Grant access"**
2. New principal: `admin@<your-domain>`
3. Role: **"Administrador da política da organização"** / **"Organization Policy Administrator"** (`roles/orgpolicy.policyAdmin`)
4. Save

### 5b. Override both org policies

Wait ~10 seconds for IAM propagation, then for *each* of these constraints:
- `iam.disableServiceAccountKeyUpload` (legacy — the one actually enforced)
- `iam.managed.disableServiceAccountKeyUpload` (managed — newer)

Navigate to:
```
https://console.cloud.google.com/iam-admin/orgpolicies/<constraint-name-with-dashes>?project=<gam-project-id>
```

For each:
1. Click **Gerenciar política** / **Manage policy**
2. Select **Substituir a política do recurso pai** / **Override parent's policy**
3. Click **adicionar uma regra** / **Add a Rule**
4. Enforcement: **Desativado** / **Off** (already default)
5. Concluído / Done
6. Definir política / Set Policy → confirm

### 5c. Re-run sakey upload

```bash
gam upload sakey
```

Now succeeds. GAM creates and uploads the service account key.

## Step 6 — Create user OAuth token

```bash
gam oauth create
```

Lists ~55 scopes with defaults preselected. **Type `c` and Enter** to accept defaults. Browser flow → log in as admin → approve. Writes `~/.gam/oauth2.txt`.

## Step 7 — Authorize domain-wide delegation scopes (UI, automatable)

```bash
gam user admin@<domain> check serviceaccount
```

First run shows all 42 scopes **FAIL**. GAM prints a URL like `https://gam-shortn.appspot.com/wy26xk` that redirects to admin.google.com with all scopes pre-filled.

Drive via playwright:
1. Open the URL — it lands on the Domain-wide Delegation page
2. **"Substituir ID do cliente existente"** checkbox should already be checked
3. Click **Autorizar**
4. Toast: "O cliente OAuth XXX foi adicionado com 43 escopos"

Wait ~30 seconds, re-run:
```bash
gam user admin@<domain> check serviceaccount
```

All 42 should now PASS, and the 3 deprecated scopes (cloud-identity, cloud-platform, iam) should also PASS (PASS = NOT granted to GAM, which is correct).

## Step 8 — Sanity check

```bash
gam info domain
```

Should print Customer ID, primary domain, creation time, etc. If yes, GAM is fully operational.

## Files GAM creates

| Path | Purpose | Sensitive? |
|---|---|---|
| `~/bin/gam7/gam` | The binary | No |
| `~/.gam/gam.cfg` | Default config | No |
| `~/.gam/oauth2.txt` | User OAuth token | **Yes** — chmod 600 |
| `~/.gam/oauth2service.json` | Service account private key | **Yes** — chmod 600 |
| `~/.gam/client_secrets.json` | OAuth client config | Moderately |

## When to redo this

- New Workspace tenant (each tenant needs its own GCP project + GAM config)
- Service account key was rotated/expired (`gam rotate sakey`)
- Workspace admin disabled the GAM app in admin.google.com → API Controls
- Switching between tenants for testing (use `gam config select`)

## Common gotchas

- **GCP ToS not accepted** — APIs fail to enable. Visit https://console.developers.google.com/terms/cloud as super-admin, accept, retry.
- **Org policy blocks key upload** — Step 5 above. The error message is unmissable but the fix takes ~10 minutes including IAM propagation.
- **Workspace super-admin doesn't auto-get OrgPolicy Admin** — counter-intuitive but true on new tenants. Step 5a fixes it.
- **Browser is needed in headed mode** — playwright-cli's headless mode hits Google's bot detection on some flows. Always use `--headed` for the Cloud Console + admin.google.com parts.
- **DwD propagation delay** — after authorizing scopes, wait ~30s before re-running `check serviceaccount`. Sometimes 1-2 minutes.

## Reference

- GAM7 wiki: https://github.com/GAM-team/GAM/wiki
- Authorization steps: https://github.com/GAM-team/GAM/wiki/Authorization
- Org policy override docs: https://github.com/GAM-team/GAM/wiki/Authorization#authorize-service-account-key-uploads
