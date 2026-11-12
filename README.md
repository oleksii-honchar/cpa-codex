# cpa-codex

Docker Compose setup for [CLIProxyAPI](https://github.com/EasyClap/CliproxyAPI) (CPA) + [CPA Usage Keeper](https://github.com/Willxup/cpa-usage-keeper), replacing the Homebrew-based installation.

## Services

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| `cli-proxy-api` | `eceasy/cli-proxy-api:v7.2.49` | 8317, 1455 | CPA proxy (8317 = HTTP, 1455 = Redis queue) |
| `cpa-usage-keeper` | `ghcr.io/willxup/cpa-usage-keeper:v1.12.4` | 8080 | Usage analytics dashboard |

## Quick Start

```bash
# Change KEEPER_LOGIN_PASSWORD in .env
mc -e .env

./start.sh
```

## Web UI

### CPA Management Center

Open **http://localhost:8317/management.html** in your browser. You'll see the CPA control panel with:
- Proxy status and request stats
- API key management
- Auth file configuration
- Model settings

### Usage Keeper Dashboard

Open **http://localhost:8080** in your browser. Login with the password you set in `.env` (`KEEPER_LOGIN_PASSWORD`). The Keeper dashboard shows:
- Usage overview with request volume, tokens, and cost
- Request Events log with filtering and export
- Model/API Key composition analysis
- Credential health and quota status
- Pricing management

## Configuration

### CPA Config (`cpa/config.yaml`)

Copied from `/opt/homebrew/etc/cliproxyapi.conf` with two adaptations:
- `auth-dir` changed to `/root/.cli-proxy-api` (container path)
- `allow-remote` set to `true` (Keeper connects from Docker network)

### Environment Variables (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `CPA_MANAGEMENT_KEY` | `sk-mgmt-cliproxy` | CPA management API key |
| `KEEPER_LOGIN_PASSWORD` | `CHANGE_ME` | Keeper dashboard login password |
| `TZ` | `Europe/Madrid` | Timezone for stats and logs |

### Auth Files

Auth files (e.g. OpenAI access tokens) go in `cpa/auths/`. They're mounted at `/root/.cli-proxy-api` inside the CPA container. Copy them from your existing `~/.cli-proxy-api/`:

```bash
cp ~/.cli-proxy-api/*.json cpa/auths/
```

## Network

Isolated Docker bridge network `cpa-network` on subnet `172.21.0.0/16`. Services communicate internally via container names (e.g. `cli-proxy-api:8317`).

## Health Checks

- **CPA**: bash `/dev/tcp` port check on 8317 (no wget/curl in container)
- **Keeper**: `wget --spider` on port 8080

The Keeper starts only after CPA is healthy (`depends_on: service_healthy`).

## Migration from Homebrew

1. Stop Homebrew CPA: `brew services stop cliproxyapi`
2. Copy config: `cp /opt/homebrew/etc/cliproxyapi.conf cpa/config.yaml` (then edit as noted above)
3. Copy auths: `cp -r ~/.cli-proxy-api/* cpa/auths/`
4. Set `KEEPER_LOGIN_PASSWORD` in `.env`
5. Start: `./start.sh`
6. Verify: `docker compose ps` (both should be healthy)

## Troubleshooting

### Health check stuck in "starting"

The CPA container uses bash's `/dev/tcp` for health checks (no wget available). If the health check fails, the Keeper won't start. Check with:

```bash
docker inspect --format='{{.State.Health.Status}}' cli-proxy-api
docker compose logs cli-proxy-api | tail -20
```

### Keeper can't connect to Redis queue

- Make sure `allow-remote: true` is set in `cpa/config.yaml`
- Make sure `CPA_MANAGEMENT_KEY` is `sk-mgmt-cliproxy` (not the bcrypt hash from the config comment)
- Use Keeper v1.12.4+ — v1.2.0 has channel incompatibility with CPA v7+

### Port conflict

If Homebrew CPA is still running on port 8317, stop it first:

```bash
brew services stop cliproxyapi
```

---

## 🟢 Native mode (launchd) — PRIMARY since 2026-11-12

The stack runs as native macOS binaries under launchd: it auto-starts at login, restarts on crash, and needs **no podman VM** (the VM was costing ~1.8 GB RAM to host ~500 MB of services). The Docker Compose setup below is kept as a **cold fallback** (see "Rolling back").

| Piece | Location |
|---|---|
| Binaries | `native/bin/CLIProxyAPI` (better-cpa HEAD + version ldflags), `native/bin/cpa-usage-keeper` (pinned tag) |
| Build (rebuild after upgrades) | `bash native/build-natives.sh` — assert-first: needs clean `../better-cpa` tree + node/go toolchains |
| Launchers (what launchd runs) | `native/bin/run-cpa.sh`, `native/bin/run-keeper.sh` — source `.env`, set host-loopback addresses, `WORK_DIR=keeper/data` |
| LaunchAgents | `~/Library/LaunchAgents/io.github.oleksii-honchar.cli-proxy-api.plist`, `io.github.oleksii-honchar.cpa-usage-keeper.plist` (RunAtLoad + KeepAlive) |
| Logs (launchd stdout) | `native/logs/*.launchd.*.log` — app logs unchanged (`cpa/logs`, `keeper/data/logs`) |
| Config notes | `cpa/config.yaml` `auth-dir` is now an **absolute path** — valid natively AND inside podman (VM mounts `/Users` at identical paths) |

### Runbook

```bash
launchctl print gui/$(id -u)/io.github.oleksii-honchar.cli-proxy-api | grep state   # status
launchctl kickstart -k gui/$(id -u)/io.github.oleksii-honchar.cli-proxy-api         # restart now
launchctl bootout   gui/$(id -u)/io.github.oleksii-honchar.cli-proxy-api            # stop until next login
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.github.oleksii-honchar.cli-proxy-api.plist  # start again
# same with …/io.github.oleksii-honchar.cpa-usage-keeper for the dashboard
```

After changing `.env` or a binary: `launchctl kickstart -k` both labels.
Ports are unchanged: 8317 proxy, 8080 dashboard (1455 unused — CPA's queue is internal).

### Rolling back to containers (if ever needed)

```bash
launchctl bootout gui/$(id -u)/io.github.oleksii-honchar.cli-proxy-api
launchctl bootout gui/$(id -u)/io.github.oleksii-honchar.cpa-usage-keeper
podman machine start && podman start cli-proxy-api cpa-usage-keeper
```

### Podman Desktop note

The app remains in Login Items. Turn OFF *Settings → Resources → auto-start machine* (Podman Desktop UI) so opening it never re-spends the VM memory; nothing here needs the VM running.

*(Authored by agent session `ses_e2fbdd97cffePqsWRXefklzstH`, 2026-11-12; acceptance steps 1–6 verified that day, reboot check at first real reboot.)*
