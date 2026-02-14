#!/usr/bin/env bash
set -euo pipefail

# Sync required Supabase env vars into a Cloudflare Pages project (via API), optionally trigger a new deploy
# via a deploy hook, then poll env-health until vars are present.
#
# Usage:
#   cloudflare-pages-sync-supabase-env.sh <BASE_URL>
#
# Required env:
#   CLOUDFLARE_API_TOKEN
#   CLOUDFLARE_ACCOUNT_ID
#   CF_PAGES_PROJECT
#   NEXT_PUBLIC_SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#
# Optional env:
#   CF_PAGES_DEPLOY_HOOK_URL
#   ENV_HEALTH_TIMEOUT_SECS  (default: 600)
#
# Notes:
# - If CF_PAGES_DEPLOY_HOOK_URL is not set, this script will upsert env vars and exit 0 with a message;
#   you must still redeploy manually for env changes to take effect.

BASE_URL="${1:-}"
if [ -z "${BASE_URL:-}" ]; then
  echo "Usage: $0 <BASE_URL>" >&2
  exit 2
fi

ENV_HEALTH_TIMEOUT_SECS="${ENV_HEALTH_TIMEOUT_SECS:-600}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSERT="$ROOT/scripts/cloudflare-pages-upsert-project-env-vars.sh"

if [ ! -x "$UPSERT" ]; then
  echo "Missing script: $UPSERT" >&2
  exit 2
fi

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "jq"

echo "Cloudflare Pages: syncing Supabase env vars for hosted runtime at: ${BASE_URL%/}" >&2
"$UPSERT"

if [ -z "${CF_PAGES_DEPLOY_HOOK_URL:-}" ]; then
  echo "Cloudflare Pages: env vars were updated, but a redeploy is still required." >&2
  echo "Set CF_PAGES_DEPLOY_HOOK_URL (optional) or trigger a deploy manually in the Cloudflare UI." >&2
  exit 0
fi

echo "Cloudflare Pages: triggering deploy hook..." >&2
hook_code="$(curl -sS -m 20 -o /dev/null -w "%{http_code}" -X POST "${CF_PAGES_DEPLOY_HOOK_URL}" || echo "000")"
if [ "$hook_code" != "200" ] && [ "$hook_code" != "201" ] && [ "$hook_code" != "204" ]; then
  echo "Cloudflare Pages: deploy hook failed (HTTP $hook_code)." >&2
  exit 2
fi

echo "Polling env-health until Supabase env vars are present (timeout=${ENV_HEALTH_TIMEOUT_SECS}s)..." >&2
deadline="$(( $(date +%s) + ENV_HEALTH_TIMEOUT_SECS ))"
out="$(mktemp)"
while :; do
  now="$(date +%s)"
  if [ "$now" -ge "$deadline" ]; then
    echo "Timed out waiting for env-health to reflect hosted Supabase env vars." >&2
    echo "Last env-health response (booleans only):" >&2
    jq . "$out" >&2 || cat "$out" >&2 || true
    rm -f "$out" 2>/dev/null || true
    exit 2
  fi

  code="$(curl -sS -m 12 -o "$out" -w "%{http_code}" "${BASE_URL%/}/api/workflow/env-health" || echo "000")"
  if [ "$code" = "200" ] && jq -e '.ok == true' "$out" >/dev/null 2>&1; then
    has_env="$(jq -r '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$out" 2>/dev/null || echo "false")"
    if [ "$has_env" = "true" ]; then
      rm -f "$out" 2>/dev/null || true
      echo "env-health now reports required Supabase env vars are present." >&2
      exit 0
    fi
  fi

  sleep 15
done
