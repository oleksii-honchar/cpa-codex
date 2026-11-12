#!/usr/bin/env bash
# Build native (darwin) binaries for the CPA stack — see cpa-codex README "Native mode".
# Reprovides the exact recipes of:
#   - better-cpa/Dockerfile   (CPA, linux-cross -> here native)
#   - cpa-usage-keeper Dockerfile v1.15.9 (Vite SPA embedded via web/static.go)
set -euo pipefail

KEEPER_TAG="${KEEPER_TAG:-v1.15.9}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # cpa-codex/
BETTER_CPA="${BETTER_CPA:-$ROOT/../better-cpa}"
OUT="$ROOT/native/bin"
mkdir -p "$OUT"

fail() { echo "ASSERT-FAIL: $*" >&2; exit 1; }

# --- prereqs ---------------------------------------------------------------
command -v go >/dev/null || fail "go missing"
command -v git >/dev/null || fail "git missing"
command -v node >/dev/null || fail "node missing (needed for keeper web build)"
command -v npm >/dev/null || fail "npm missing"
[ -d "$BETTER_CPA/.git" ] || fail "better-cpa not found at $BETTER_CPA"

# --- CPA -------------------------------------------------------------------
cd "$BETTER_CPA"
[ -z "$(git status --porcelain)" ] || fail "better-cpa tree not clean"
VERSION="$(git describe --tags --always --dirty)"
GIT_SHA="$(git rev-parse --short HEAD)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[cpa] building version=$VERSION rev=$GIT_SHA"
CGO_ENABLED=1 go build -buildvcs=false \
  -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${GIT_SHA}' -X 'main.BuildDate=${BUILD_DATE}'" \
  -o "$OUT/CLIProxyAPI" ./cmd/server/

# --- Usage Keeper (pinned tag; no upgrade bundled) --------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --quiet --depth 1 --branch "$KEEPER_TAG" https://github.com/Willxup/cpa-usage-keeper "$TMP/keeper"
cd "$TMP/keeper/web"
npm ci --no-audit --no-fund
npm run build
cd "$TMP/keeper"
CGO_ENABLED=1 go build -ldflags="-s -w -X cpa-usage-keeper/internal/version.Version=${KEEPER_TAG}" \
  -o "$OUT/cpa-usage-keeper" ./cmd/server/main.go

# --- verify placement (file-safe: no grep -q in pipelines under pipefail) --
has_str() { # file, needle
  local sf="${TMP}/strings.bin"
  strings "$1" > "$sf"
  grep -qF "$2" "$sf" || fail "no string '$2' in $1"
}
file "$OUT/CLIProxyAPI" > "${TMP}/f1" && grep -q 'Mach-O 64-bit executable arm64' "${TMP}/f1" || fail "CPA binary not Mach-O arm64"
file "$OUT/cpa-usage-keeper" > "${TMP}/f2" && grep -q 'Mach-O 64-bit executable arm64' "${TMP}/f2" || fail "keeper binary not Mach-O arm64"
has_str "$OUT/CLIProxyAPI" "$VERSION"
has_str "$OUT/cpa-usage-keeper" "$KEEPER_TAG"
echo "OK: $OUT/CLIProxyAPI ($VERSION) + $OUT/cpa-usage-keeper ($KEEPER_TAG)"
