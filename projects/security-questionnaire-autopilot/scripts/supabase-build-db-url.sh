#!/usr/bin/env bash
set -euo pipefail

# Build SUPABASE_DB_URL deterministically from:
# - Supabase project ref (SUPABASE_PROJECT_REF)
# - Supabase DB password (SUPABASE_DB_PASSWORD)
#
# This prints a secret-bearing connection string to stdout. In CI, capture it
# into an env var (e.g. $GITHUB_ENV) without echoing it to logs.
#
# Env (required, unless flags provided):
#   SUPABASE_PROJECT_REF
#   SUPABASE_DB_PASSWORD
#
# Flags (override env):
#   --ref <project_ref>
#   --db-password <password>
#
# Env (optional):
#   SUPABASE_DB_USER (default: postgres)
#   SUPABASE_DB_NAME (default: postgres)
#   SUPABASE_DB_PORT (default: 5432)

REF="${SUPABASE_PROJECT_REF:-}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD:-}"

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --ref)
      REF="${2:-}"; shift 2 ;;
    --db-password)
      DB_PASSWORD="${2:-}"; shift 2 ;;
    --stdout)
      # Backwards/forwards-compat no-op (script already writes to stdout).
      shift 1 ;;
    *)
      echo "Unknown arg: ${1:-}" >&2
      exit 2
      ;;
  esac
done

if [ -z "${REF:-}" ]; then
  echo "Missing SUPABASE_PROJECT_REF (or --ref)" >&2
  exit 2
fi
if [ -z "${DB_PASSWORD:-}" ]; then
  echo "Missing SUPABASE_DB_PASSWORD (or --db-password)" >&2
  exit 2
fi

USER="${SUPABASE_DB_USER:-postgres}"
DB="${SUPABASE_DB_NAME:-postgres}"
PORT="${SUPABASE_DB_PORT:-5432}"
HOST="db.${REF}.supabase.co"

urlencode() {
  local s="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$s"
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    node -e "process.stdout.write(encodeURIComponent(process.argv[1] ?? ''))" "$s"
    return 0
  fi
  echo "Missing dependency: python3 or node (needed for URL encoding)" >&2
  exit 2
}

ENC_PASS="$(urlencode "$DB_PASSWORD")"
printf 'postgresql://%s:%s@%s:%s/%s' "$USER" "$ENC_PASS" "$HOST" "$PORT" "$DB"
