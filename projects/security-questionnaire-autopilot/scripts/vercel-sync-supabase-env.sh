#!/usr/bin/env bash
set -euo pipefail

# Sync required Supabase env vars into a Vercel Project, then redeploy and wait for env-health.
#
# Usage:
#   vercel-sync-supabase-env.sh <BASE_URL>
#
# Required env:
#   VERCEL_TOKEN
#   VERCEL_PROJECT_ID or VERCEL_PROJECT
#   NEXT_PUBLIC_SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#
# Optional env:
#   VERCEL_TEAM_ID, VERCEL_TEAM_SLUG
#   VERCEL_ENV_TARGETS       Default: production,preview
#   SKIP_REDEPLOY=1          Only upsert env vars; do not trigger redeploy/poll
#   ENV_HEALTH_TIMEOUT_SECS  Default: 600

BASE_URL="${1:-}"

SKIP_REDEPLOY="${SKIP_REDEPLOY:-0}"
ENV_HEALTH_TIMEOUT_SECS="${ENV_HEALTH_TIMEOUT_SECS:-600}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSERT="$ROOT/scripts/vercel-upsert-project-env-vars.sh"
REDEPLOY="$ROOT/scripts/vercel-redeploy-from-base-url.sh"

if [ -z "${BASE_URL:-}" ]; then
  echo "Usage: vercel-sync-supabase-env.sh <BASE_URL>" >&2
  exit 2
fi

if [ ! -x "$UPSERT" ]; then
  echo "Missing script: $UPSERT" >&2
  exit 2
fi
if [ ! -x "$REDEPLOY" ]; then
  echo "Missing script: $REDEPLOY" >&2
  exit 2
fi

echo "Vercel: syncing Supabase env vars for hosted runtime at: ${BASE_URL%/}" >&2
"$UPSERT"

if [ "$SKIP_REDEPLOY" = "1" ]; then
  echo "SKIP_REDEPLOY=1: skipping redeploy + env-health polling." >&2
  exit 0
fi

set +e
"$REDEPLOY" "$BASE_URL"
redeploy_rc="$?"
set -e
if [ "$redeploy_rc" != "0" ]; then
  echo "Vercel redeploy step failed. Env vars may be set but not yet active until the next deploy." >&2
  exit 2
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "Missing curl/jq; cannot poll env-health. Redeploy was triggered." >&2
  exit 0
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
