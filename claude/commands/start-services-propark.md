---
name: start-services
description:
  Start all ProPark local services in the correct ports. Starts MySQL Docker
  container, then lp-gated (5173/6543), proparcs (3000/5001), and
  lightning-pay-admin (3123/8001). Use when setting up the full local dev
  stack for E2E testing or manual testing.
allowed-tools:
  - Bash
  - Read
---

# Start All ProPark Local Services

Start every service in the local ProPark dev stack in the correct order.

## Port Map

| Service                        | Port | Start command (from repo root)              |
|-------------------------------|------|---------------------------------------------|
| MySQL (Docker)                | 3306 | `cd proparcs-models && npm run db:start`    |
| lp-gated frontend             | 5173 | `cd lp-gated && npm start`                  |
| lp-gated API (functions)      | 6543 | `cd lp-gated/functions && npm start`        |
| proparcs frontend             | 3000 | `cd proparcs && npm start`                  |
| proparcs Firebase emulator    | 5001 | `cd proparcs/functions && npm run serve`    |
| lightning-pay-admin frontend  | 3123 | `cd lightning-pay-admin && npm start`       |
| lightning-pay-admin API       | 8001 | `cd lightning-pay-admin/functions && npm start` |

## Steps

### 1. Check Docker Desktop is running

```bash
docker info > /dev/null 2>&1 && echo "Docker running" || echo "Docker NOT running — start Docker Desktop first"
```

If Docker is not running, tell the user to open Docker Desktop before continuing.

### 2. Check for port conflicts before starting

```bash
for port in 5173 6543 3000 5001 3123 8001 3306; do
  pids=$(lsof -ti :$port 2>/dev/null)
  if [ -n "$pids" ]; then
    echo "  :$port IN USE (PID $pids)"
  else
    echo "  :$port free"
  fi
done
```

If any port is in use, ask the user whether to kill those processes or abort. Do not proceed past this step if there are conflicts without user confirmation.

### 3. Use the master start script

The `start-local.sh` script handles everything in the right order (DB → seed → apps):

```bash
cd ~/propark/repos && ./start-local.sh 2>&1
```

**Available flags — ask the user which they want before running:**
- Default (no flags): pull latest develop, reinstall deps, reset + reseed DB (~3 min wait), start all apps
- `--no-pull`: skip `git pull` (use if branches are already up to date)
- `--no-install`: skip `npm install` (use if deps haven't changed)
- `--no-seed`: skip DB reset/reseed (use to keep existing data)

Fastest restart (keep existing data, skip pull and install):
```bash
cd ~/propark/repos && ./start-local.sh --no-pull --no-install --no-seed 2>&1
```

### 4. Wait for DB seeder (if seeding)

If the DB was seeded, `start-local.sh` waits 3 minutes automatically. Inform the user the seeder takes ~3 min before the apps become usable.

After seeder finishes, QA users are seeded automatically. To seed them manually:
```bash
cd ~/propark/repos/proparcs-models && node scripts/seed-local-qa-users.js
```

### 5. Verify all services are up on the EXACT required ports

**Port assignments are fixed — do not accept any service on a different port. Auto tests will fail.**

```bash
for port in 5173 6543 3000 5001 3123 8001; do
  pids=$(lsof -ti :$port 2>/dev/null)
  if [ -n "$pids" ]; then
    echo "  :$port UP (PID $pids)"
  else
    echo "  :$port NOT running"
  fi
done
```

If any service is not on its assigned port (e.g. proparcs landed on 3001 or 3002 instead of 3000):
1. Check what's occupying the correct port: `lsof -i :<port>`
2. Kill the misplaced service process
3. Kill any process blocking the correct port
4. Restart the service with the explicit PORT env var:
   - proparcs: `cd ~/propark/repos/proparcs && PORT=3000 npm start >> ~/propark/repos/logs/proparcs.log 2>&1 &`
5. Re-verify the port is now correct before reporting success

**Do not report a service as UP unless it is on its exact assigned port.**

### 6. Report status

Print a clean summary:

```
App                     URL
─────────────────────────────────────────────
lp-gated                http://localhost:5173
lp-gated API            http://localhost:6543
proparcs                http://localhost:3000
proparcs API            http://localhost:5001 (Firebase emulator)
lightning-pay-admin     http://localhost:3123
LPA API                 http://localhost:8001
MySQL                   127.0.0.1:3306
```

Note any service that failed to start and suggest checking `~/propark/repos/logs/<service>.log`.

## Logs

All logs are written to `~/propark/repos/logs/`:
- `lp-gated.log` / `lp-gated-functions.log`
- `proparcs.log` / `proparcs-functions.log`
- `lpa.log` / `lpa-functions.log`
- `proparcs-stripe.log`

## Common Issues

| Error | Fix |
|-------|-----|
| Port already in use | Run `/stop-services` first, then retry |
| `404 on @projectinflection/*` | npm token expired — get new one from Manoj, update `.npmrc` in each repo root and functions |
| DB tables don't exist | Seeder still running — wait 2–3 min after `db:start` |
| `Unknown column 'location.deleted_at'` | `cd proparcs-models && git pull && npm run db:reset && npm run db:start` |
| proparcs "Location not found" or blank page | `VITE_FUNCTIONS_URL` project path must match `.firebaserc` default project — run `set-env.js` |
| LPA "not authorized" on Google login | Add your email to `lpa-rodrigo-costa` Firebase Authentication users |
| lp-gated login button does nothing | Use Phone Simulator (dev mode) — reCAPTCHA is always active locally |
