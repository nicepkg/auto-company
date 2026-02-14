#!/usr/bin/env bash
set -euo pipefail

# Upsert Supabase env vars on a Vercel Project via REST API.
#
# Purpose: unblock hosted /api/workflow/* runtime by ensuring these exist on the hosting provider:
#   - NEXT_PUBLIC_SUPABASE_URL
#   - SUPABASE_SERVICE_ROLE_KEY
#
# Never prints secret values.
#
# Required env:
#   VERCEL_TOKEN
#   VERCEL_PROJECT_ID  OR  VERCEL_PROJECT
#   NEXT_PUBLIC_SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#
# Optional env (team-scoped projects):
#   VERCEL_TEAM_ID
#   VERCEL_TEAM_SLUG
#
# Optional:
#   VERCEL_ENV_TARGET (default: production)  # "production" | "preview"
#
# Note:
# - This wrapper exists for backwards compatibility with older workflows/docs.
# - Prefer calling: vercel-upsert-project-env-vars.sh (supports multiple targets and "sensitive" secrets).

VERCEL_TOKEN="${VERCEL_TOKEN:-}"
VERCEL_PROJECT_ID="${VERCEL_PROJECT_ID:-}"
VERCEL_PROJECT="${VERCEL_PROJECT:-}"
VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-}"
VERCEL_TEAM_SLUG="${VERCEL_TEAM_SLUG:-}"
VERCEL_ENV_TARGET="${VERCEL_ENV_TARGET:-production}"

SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [ "${VERCEL_ENV_TARGET}" = "development" ]; then
  echo "Refusing VERCEL_ENV_TARGET=development (SUPABASE_SERVICE_ROLE_KEY must be stored as sensitive and is not allowed for development)." >&2
  echo "Fix: set VERCEL_ENV_TARGET=production (recommended) or preview." >&2
  exit 2
fi

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VERCEL_ENV_TARGETS="${VERCEL_ENV_TARGET}"
if [ "${VERCEL_ENV_TARGET}" = "production" ]; then
  # Preserve legacy behavior: default this wrapper to production-only unless the caller opts in.
  export VERCEL_SKIP_PREVIEW=1
else
  export VERCEL_SKIP_PREVIEW=0
fi

echo "Vercel: syncing Supabase env vars to target=${VERCEL_ENV_TARGET}" >&2
"${SCRIPTS_DIR}/vercel-upsert-project-env-vars.sh" >/dev/null
