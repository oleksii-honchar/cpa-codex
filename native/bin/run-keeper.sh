#!/usr/bin/env bash
# LaunchAgent payload — see run-cpa.sh header for launchctl usage.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # cpa-codex/
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; }

export CPA_BASE_URL="http://127.0.0.1:8317"          # was compose-service DNS; same host now
export REDIS_QUEUE_ADDR="127.0.0.1:8317"
export CPA_MANAGEMENT_KEY="${CPA_MANAGEMENT_KEY:?CPA_MANAGEMENT_KEY missing in .env}"
export AUTH_ENABLED="true"
export LOGIN_PASSWORD="${KEEPER_LOGIN_PASSWORD:?KEEPER_LOGIN_PASSWORD missing in .env}"
export WORK_DIR="$ROOT/keeper/data"                    # same SQLite as before — no data move

cd "$ROOT/keeper"
exec "$ROOT/native/bin/cpa-usage-keeper"
