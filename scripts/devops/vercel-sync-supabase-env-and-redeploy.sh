#!/usr/bin/env bash
set -euo pipefail

# Local/operator helper: upsert Supabase env vars on Vercel + trigger redeploy, then wait for env-health.
#
# Never prints secret values.
#
# Usage:
#   scripts/devops/vercel-sync-supabase-env-and-redeploy.sh <BASE_URL>
#
# Required env:
#   VERCEL_TOKEN
#   VERCEL_PROJECT_ID or VERCEL_PROJECT
#   NEXT_PUBLIC_SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#
# Optional env:
#   VERCEL_TEAM_ID, VERCEL_TEAM_SLUG
#   TIMEOUT_SECONDS (default: 600)

BASE_URL="${1:-}"
if [ -z "${BASE_URL:-}" ]; then
  echo "Usage: $0 <BASE_URL>" >&2
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

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNCER="$ROOT/projects/security-questionnaire-autopilot/scripts/vercel-sync-supabase-env.sh"

if [ ! -x "$SYNCER" ]; then
  echo "Missing script: $SYNCER" >&2
  exit 2
fi

ENV_HEALTH_TIMEOUT_SECS="${TIMEOUT_SECONDS:-600}" \
  "$SYNCER" "${BASE_URL%/}"
