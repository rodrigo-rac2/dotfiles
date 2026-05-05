---
name: service-status
description: Use when the user wants to check which ProPark local services are running, asks "are services up", "what's running", or "check service status". Reports port status and URLs for the full dev stack.
allowed-tools: Bash
---

# ProPark Service Status

Check which local ProPark services are currently running and display a clean summary.

## Steps

### 1. Check each service port

```bash
for port in 5173 6543 3000 5001 3123 8001 3306; do
  pids=$(lsof -ti :$port 2>/dev/null)
  if [ -n "$pids" ]; then
    echo ":$port UP"
  else
    echo ":$port DOWN"
  fi
done
```

### 2. Display status table

Print a status table using the results. Mark each row UP or DOWN:

```
App                     URL                                      Status
──────────────────────────────────────────────────────────────────────
lp-gated                http://localhost:5173                    UP
lp-gated API            http://localhost:6543                    UP
proparcs                http://localhost:3000                    UP
proparcs API            http://localhost:5001 (Firebase emul.)  UP
lightning-pay-admin     http://localhost:3123                    UP
LPA API                 http://localhost:8001                    UP
MySQL                   127.0.0.1:3306                           UP
```

### 3. Summary line

- If all 7 are up: `All services running.`
- If some are down: `X/7 services running.` and list the ones that are down.
- If all are down: `No services running. Run /start-services to start the stack.`
