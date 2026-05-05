---
name: stop-services
description:
  Stop all ProPark local services. Kills processes on ports 5173, 6543, 3000,
  5001, 3123, 8001 and stops the MySQL Docker container. Use when you need to
  shut down the full local dev stack.
allowed-tools:
  - Bash
---

# Stop All ProPark Local Services

Stop every service in the local ProPark dev stack.

## Services to stop

| Service                        | Port |
|-------------------------------|------|
| lp-gated frontend             | 5173 |
| lp-gated API (functions)      | 6543 |
| proparcs frontend             | 3000 |
| proparcs Firebase emulator    | 5001 |
| lightning-pay-admin frontend  | 3123 |
| lightning-pay-admin API       | 8001 |
| MySQL (Docker)                | 3306 |

## Steps

1. First try the managed stop script (it uses the PID file from start-local.sh):

```bash
cd ~/propark/repos && ./stop-local.sh 2>&1
```

2. Then force-kill anything still running on service ports (covers processes started outside the script):

```bash
for port in 5173 6543 3000 5001 3123 8001; do
  pids=$(lsof -ti :$port 2>/dev/null)
  if [ -n "$pids" ]; then
    echo "Killing port $port: PIDs $pids"
    kill -9 $pids
  else
    echo "Port $port: already free"
  fi
done
```

3. Stop the MySQL Docker container:

```bash
cd ~/propark/repos/proparcs-models && npm run db:stop 2>&1
```

4. Confirm all ports are clear:

```bash
for port in 5173 6543 3000 5001 3123 8001 3306; do
  pids=$(lsof -ti :$port 2>/dev/null)
  if [ -n "$pids" ]; then
    echo "  :$port still in use (PID $pids)"
  else
    echo "  :$port free"
  fi
done
```

Report which ports were stopped and confirm everything is clear.
