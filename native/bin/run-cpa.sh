#!/usr/bin/env bash
# LaunchAgent payload — do not run by hand for start/stop; use:
#   launchctl bootstrap  gui/$(id -u) ~/Library/LaunchAgents/io.github.oleksii-honchar.cli-proxy-api.plist
#   launchctl bootout    gui/$(id -u)/io.github.oleksii-honchar.cli-proxy-api
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # cpa-codex/
[ -f "$ROOT/.env" ] && { set -a; . "$ROOT/.env"; set +a; } # TZ etc.
cd "$ROOT/cpa"                                              # working dir = service root (config.yaml, logs/, ./)
exec "$ROOT/native/bin/CLIProxyAPI"
