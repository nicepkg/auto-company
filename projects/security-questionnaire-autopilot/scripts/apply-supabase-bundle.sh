#!/usr/bin/env bash
set -euo pipefail

# Apply the paste-ready bundle to a Supabase Postgres project using node + pg.
# This is the lowest-friction path in environments without `psql` or the Supabase CLI.
#
# Required env:
#   SUPABASE_DB_URL
#
# Alternative required env (deterministic URL build, avoids copy/paste):
#   SUPABASE_PROJECT_REF
#   SUPABASE_DB_PASSWORD
#
# Optional env:
#   SUPABASE_DB_SSL=true|false (default true)
#   SUPABASE_DB_SSL_REJECT_UNAUTHORIZED=true|false (default true)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUNDLE_DEFAULT="supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
BUNDLE_IN="${1:-$BUNDLE_DEFAULT}"
VERIFY="${VERIFY_SUPABASE_BUNDLE_APPLY:-1}"

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Missing env var: $name" >&2
    exit 2
  fi
}

require_bin node
require_bin npm

BUNDLE="$BUNDLE_IN"
if [ -n "$BUNDLE" ] && [ "${BUNDLE#/}" != "$BUNDLE" ]; then
  # Absolute path; keep as-is.
  :
else
  # Workspace-relative path (relative to project root).
  BUNDLE="$ROOT/$BUNDLE"
fi

if [ ! -f "$BUNDLE" ]; then
  echo "Bundle not found: $BUNDLE_IN" >&2
  exit 2
fi

# Allow callers to provide (ref + db password) instead of pasting a full URL.
if [ -z "${SUPABASE_DB_URL:-}" ]; then
  if [ -n "${SUPABASE_PROJECT_REF:-}" ] && [ -n "${SUPABASE_DB_PASSWORD:-}" ]; then
    # Build deterministically and URL-encode the password.
    export SUPABASE_DB_URL="$(
      SUPABASE_PROJECT_REF="$SUPABASE_PROJECT_REF" \
      SUPABASE_DB_PASSWORD="$SUPABASE_DB_PASSWORD" \
      "$ROOT/scripts/supabase-build-db-url.sh" --stdout
    )"
  else
    echo "Missing env var: SUPABASE_DB_URL" >&2
    echo "Alternatively set: SUPABASE_PROJECT_REF and SUPABASE_DB_PASSWORD" >&2
    exit 2
  fi
fi

# scripts/apply-supabase-sql.mjs imports `pg`; ensure deps exist.
if [ ! -d node_modules/pg ]; then
  echo "node_modules missing; running npm ci (project: $ROOT)" >&2
  npm ci
fi

node scripts/verify-dashboard-sql-bundle.mjs --bundle "$BUNDLE" >/dev/null
node scripts/apply-supabase-sql.mjs "$BUNDLE"

if [ -n "${VERIFY:-}" ] && [ "$VERIFY" != "0" ]; then
  mkdir -p "$ROOT/runs"
  node scripts/verify-supabase-bundle-applied.mjs >"$ROOT/runs/supabase-verify.json"
  echo "Supabase bundle verification: PASS (runs/supabase-verify.json)" >&2
fi
