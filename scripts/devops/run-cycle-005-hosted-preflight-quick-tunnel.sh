#!/usr/bin/env bash
set -euo pipefail

# Purpose:
# - Create a temporarily public BASE_URL for the hosted Next.js workflow runtime using a Cloudflare Quick Tunnel.
# - Dispatch Cycle 005 hosted persistence evidence workflow in preflight-only mode against that BASE_URL.
#
# Why:
# - Unblocks BASE_URL validation + env-health checks even when you don't yet have Vercel/Cloudflare Pages credentials.
# - Note: This is not a stable production origin. Do NOT persist this URL into HOSTED_WORKFLOW_BASE_URL_CANDIDATES.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-hosted-preflight-quick-tunnel.sh [flags]

Flags:
  --repo OWNER/REPO    Target repo to dispatch workflow on (default: junhengz/auto-company)
  --port PORT          Local port for Next.js runtime (default: 18082)
  --install-deps       Run npm ci in hosted runtime project before starting (default: off)
  --no-dispatch        Only print the discovered Quick Tunnel BASE_URL (default: off)

Environment:
  NEXT_PUBLIC_SUPABASE_URL     Optional. If unset, a placeholder is used to satisfy env-health presence checks.
  SUPABASE_SERVICE_ROLE_KEY    Optional. If unset, a placeholder is used to satisfy env-health presence checks.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

REPO="junhengz/auto-company"
PORT="18082"
INSTALL_DEPS="0"
NO_DISPATCH="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --port) PORT="${2:-}"; shift 2 ;;
    --install-deps) INSTALL_DEPS="1"; shift 1 ;;
    --no-dispatch) NO_DISPATCH="1"; shift 1 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "rg"
require_bin "gh"
require_bin "node"
require_bin "npm"
require_bin "cloudflared"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT/projects/security-questionnaire-autopilot"
RUN_DIR="$ROOT/logs/devops/quick-tunnel-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"

NEXT_PID=""
CF_PID=""
TAIL_PID=""
cleanup() {
  set +e
  if [ -n "${TAIL_PID:-}" ]; then
    kill "$TAIL_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "${CF_PID:-}" ]; then
    kill "$CF_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "${NEXT_PID:-}" ]; then
    kill "$NEXT_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [ ! -d "$PROJECT" ]; then
  echo "Missing project directory: $PROJECT" >&2
  exit 2
fi

if [ "$INSTALL_DEPS" = "1" ] || [ ! -d "$PROJECT/node_modules" ]; then
  (cd "$PROJECT" && npm ci)
fi

NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://example.supabase.co}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-placeholder-service-role-key}"

echo "Starting Next.js runtime on http://127.0.0.1:${PORT} (logs: $RUN_DIR/next.log)" >&2
(cd "$PROJECT" && \
  NEXT_PUBLIC_SUPABASE_URL="$NEXT_PUBLIC_SUPABASE_URL" \
  SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
  npm run dev -- -p "$PORT") >"$RUN_DIR/next.log" 2>&1 &
NEXT_PID="$!"

echo "Waiting for local env-health..." >&2
for _ in $(seq 1 60); do
  code="$(curl -sS -m 2 -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/api/workflow/env-health" || echo "000")"
  if [ "$code" = "200" ]; then
    break
  fi
  sleep 0.5
done

code="$(curl -sS -m 3 -o "$RUN_DIR/env-health.local.json" -w "%{http_code}" "http://127.0.0.1:${PORT}/api/workflow/env-health" || echo "000")"
if [ "$code" != "200" ]; then
  echo "Local env-health failed (HTTP $code). See: $RUN_DIR/env-health.local.json and $RUN_DIR/next.log" >&2
  exit 2
fi

echo "Starting Cloudflare Quick Tunnel (logs: $RUN_DIR/cloudflared.log)" >&2
cloudflared tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate >"$RUN_DIR/cloudflared.log" 2>&1 &
CF_PID="$!"

BASE_URL=""
echo "Waiting for trycloudflare URL..." >&2

URL_FILE="$RUN_DIR/base-url.txt"
rm -f "$URL_FILE"

# Follow the log as it is written and capture the first trycloudflare URL without racing file reads.
(tail -n +1 -F "$RUN_DIR/cloudflared.log" 2>/dev/null || true) | \
  awk '
    {
      if (match($0, /https:\/\/[a-z0-9-]+\.trycloudflare\.com/)) {
        print substr($0, RSTART, RLENGTH)
        fflush()
        exit 0
      }
    }
  ' >"$URL_FILE" 2>/dev/null &
TAIL_PID="$!"

for _ in $(seq 1 120); do
  if [ -s "$URL_FILE" ]; then
    BASE_URL="$(head -n 1 "$URL_FILE" | tr -d '\r' || true)"
    break
  fi
  sleep 0.5
done

if [ -z "${BASE_URL:-}" ]; then
  echo "Failed to extract trycloudflare URL from: $RUN_DIR/cloudflared.log" >&2
  echo "cloudflared.log tail:" >&2
  tail -n 80 "$RUN_DIR/cloudflared.log" >&2 || true
  exit 2
fi

echo "Quick Tunnel BASE_URL: $BASE_URL" >&2

echo "Probing tunnel env-health..." >&2
code="$(curl -sS -m 6 -o "$RUN_DIR/env-health.tunnel.json" -w "%{http_code}" "${BASE_URL}/api/workflow/env-health" || echo "000")"
if [ "$code" != "200" ]; then
  echo "Tunnel env-health failed (HTTP $code). See: $RUN_DIR/env-health.tunnel.json" >&2
  exit 2
fi

if [ "$NO_DISPATCH" = "1" ]; then
  printf '%s\n' "$BASE_URL"
  exit 0
fi

echo "Dispatching Cycle 005 preflight-only against BASE_URL=$BASE_URL on repo=$REPO" >&2
echo "Note: skip_sql_apply=false so the workflow does not run supabase-health during preflight." >&2

"$ROOT/scripts/devops/run-cycle-005-hosted-persistence-evidence.sh" \
  --repo "$REPO" \
  --preflight-only \
  --skip-sql-apply false \
  --base-url "$BASE_URL"
