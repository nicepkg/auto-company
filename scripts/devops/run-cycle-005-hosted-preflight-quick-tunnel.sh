#!/usr/bin/env bash
set -euo pipefail

# Purpose:
# - Create a temporarily public BASE_URL for the hosted Next.js workflow runtime using a Cloudflare Quick Tunnel.
# - Dispatch Cycle 005 hosted persistence evidence workflow in preflight-only mode against that BASE_URL.
#
# Note:
# - This is not a stable production origin. Do NOT persist this URL into HOSTED_WORKFLOW_BASE_URL_CANDIDATES.
# - This helper intentionally skips `supabase-health` to allow env-only validation while Supabase is still pending.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-hosted-preflight-quick-tunnel.sh [flags]

Flags:
  --repo OWNER/REPO    Target repo to dispatch workflow on (default: junhengz/auto-company)
  --ref REF            Git ref to run workflow from (branch/tag/SHA). Use when running workflow changes from a non-default branch.
  --port PORT          Local port for Next.js runtime (default: 18082)
  --install-deps       Run npm ci in hosted runtime project before starting (default: off)
  --no-dispatch        Only print the discovered Quick Tunnel BASE_URL (default: off)
  --no-cleanup         Leave local Next.js + cloudflared running (default: off)

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
REF=""
PORT="18082"
INSTALL_DEPS="0"
NO_DISPATCH="0"
NO_CLEANUP="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --port) PORT="${2:-}"; shift 2 ;;
    --install-deps) INSTALL_DEPS="1"; shift 1 ;;
    --no-dispatch) NO_DISPATCH="1"; shift 1 ;;
    --no-cleanup) NO_CLEANUP="1"; shift 1 ;;
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
require_bin "jq"
require_bin "getent"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT/projects/security-questionnaire-autopilot"
RUN_DIR="$ROOT/logs/devops/quick-tunnel-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"

NEXT_PID_FILE="$RUN_DIR/next.pid"
CF_PID_FILE="$RUN_DIR/cloudflared.pid"

cleanup() {
  set +e
  if [ "$NO_CLEANUP" = "1" ]; then
    return 0
  fi
  if [ -f "$CF_PID_FILE" ]; then
    kill "$(cat "$CF_PID_FILE" 2>/dev/null)" >/dev/null 2>&1 || true
  fi
  if [ -f "$NEXT_PID_FILE" ]; then
    kill "$(cat "$NEXT_PID_FILE" 2>/dev/null)" >/dev/null 2>&1 || true
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
  nohup env \
    NEXT_PUBLIC_SUPABASE_URL="$NEXT_PUBLIC_SUPABASE_URL" \
    SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
    npm run dev -- -p "$PORT" \
    >"$RUN_DIR/next.log" 2>&1 & echo $! >"$NEXT_PID_FILE")

echo "Waiting for local env-health..." >&2
for _ in $(seq 1 120); do
  code="$(curl -sS -m 2 -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/api/workflow/env-health" 2>/dev/null || echo "000")"
  if [ "$code" = "200" ]; then
    break
  fi
  sleep 0.5
done
code="$(curl -sS -m 3 -o "$RUN_DIR/env-health.local.json" -w "%{http_code}" "http://127.0.0.1:${PORT}/api/workflow/env-health" 2>/dev/null || echo "000")"
if [ "$code" != "200" ]; then
  echo "Local env-health failed (HTTP $code). See: $RUN_DIR/env-health.local.json and $RUN_DIR/next.log" >&2
  exit 2
fi
if ! jq -e '.ok == true and .env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$RUN_DIR/env-health.local.json" >/dev/null 2>&1; then
  echo "Local env-health did not report required booleans. See: $RUN_DIR/env-health.local.json" >&2
  exit 2
fi

echo "Starting Cloudflare Quick Tunnel (logs: $RUN_DIR/cloudflared.log)" >&2
nohup cloudflared tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate >"$RUN_DIR/cloudflared.log" 2>&1 & echo $! >"$CF_PID_FILE"

BASE_URL=""
echo "Waiting for trycloudflare URL..." >&2
for _ in $(seq 1 240); do
  BASE_URL="$(rg -o -m 1 'https://[a-z0-9-]+\\.trycloudflare\\.com' "$RUN_DIR/cloudflared.log" 2>/dev/null | head -n 1 || true)"
  BASE_URL="$(printf '%s' "${BASE_URL:-}" | tr -d '\r' | head -n 1)"
  if [ -n "${BASE_URL:-}" ]; then
    break
  fi
  sleep 0.25
done

if [ -z "${BASE_URL:-}" ]; then
  echo "Failed to extract trycloudflare URL from: $RUN_DIR/cloudflared.log" >&2
  tail -n 120 "$RUN_DIR/cloudflared.log" >&2 || true
  exit 2
fi

echo "Quick Tunnel BASE_URL: $BASE_URL" >&2

host="${BASE_URL#https://}"
host="${host#http://}"
host="${host%%/*}"

echo "Waiting for tunnel DNS to resolve (host=$host)..." >&2
deadline_dns="$(( $(date +%s) + 90 ))"
while [ "$(date +%s)" -lt "$deadline_dns" ]; do
  if getent hosts "$host" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! getent hosts "$host" >/dev/null 2>&1; then
  echo "Tunnel host did not resolve within timeout: $host" >&2
  exit 2
fi

echo "Probing tunnel env-health (retry up to 90s)..." >&2
deadline="$(( $(date +%s) + 90 ))"
code="000"
while [ "$(date +%s)" -lt "$deadline" ]; do
  code="$(curl -sS -m 10 -o "$RUN_DIR/env-health.tunnel.json" -w "%{http_code}" "${BASE_URL}/api/workflow/env-health" 2>/dev/null || echo "000")"
  if [ "$code" = "200" ]; then
    break
  fi
  sleep 1
done
if [ "$code" != "200" ]; then
  echo "Tunnel env-health failed (HTTP $code). See: $RUN_DIR/env-health.tunnel.json" >&2
  exit 2
fi
if ! jq -e '.ok == true and .env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$RUN_DIR/env-health.tunnel.json" >/dev/null 2>&1; then
  echo "Tunnel env-health did not report required booleans. See: $RUN_DIR/env-health.tunnel.json" >&2
  exit 2
fi

if [ "$NO_DISPATCH" = "1" ]; then
  printf '%s\n' "$BASE_URL"
  exit 0
fi

echo "Dispatching Cycle 005 preflight-only against BASE_URL=$BASE_URL on repo=$REPO" >&2
echo "Note: this run validates BASE_URL + env-health only (supabase-health is skipped)." >&2

start_ts="$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")"
ref_args=()
if [ -n "${REF:-}" ]; then
  ref_args+=(--ref "$REF")
fi
gh workflow run cycle-005-hosted-persistence-evidence.yml -R "$REPO" \
  "${ref_args[@]}" \
  -f preflight_only=true \
  -f skip_sql_apply=true \
  -f preflight_require_supabase_health=false \
  -f persist_base_url_candidates=false \
  -f enable_autorun_after_preflight=false \
  -f base_url="$BASE_URL" >/dev/null

run_dbid="$(gh run list -R "$REPO" --workflow cycle-005-hosted-persistence-evidence.yml -L 10 --json databaseId,createdAt -q \"map(select(.createdAt >= \\\"$start_ts\\\")) | .[0].databaseId\" 2>/dev/null || true)"
if [ -z "${run_dbid:-}" ] || [ "${run_dbid:-}" = "null" ]; then
  run_dbid="$(gh run list -R "$REPO" --workflow cycle-005-hosted-persistence-evidence.yml -L 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
fi
if [ -z "${run_dbid:-}" ] || [ "${run_dbid:-}" = "null" ]; then
  echo "Failed to locate the dispatched run via gh." >&2
  exit 2
fi

run_url="$(gh run view -R "$REPO" "$run_dbid" --json htmlUrl -q '.htmlUrl' 2>/dev/null || true)"
echo "GHA run databaseId: $run_dbid" >&2
if [ -n "${run_url:-}" ] && [ "${run_url:-}" != "null" ]; then
  echo "GHA run url: $run_url" >&2
fi

gh run watch -R "$REPO" "$run_dbid" --exit-status
