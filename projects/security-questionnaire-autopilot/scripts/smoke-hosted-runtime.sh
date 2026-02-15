#!/usr/bin/env bash
set -euo pipefail

# Smoke-check a deployed workflow runtime at BASE_URL.
#
# Checks:
# - GET  /api/workflow/env-health
# - GET  /api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1
# - POST /api/workflow/db-evidence (optional, requires run_id)
#
# Outputs JSON files into OUT_DIR (default: /tmp/hosted-runtime-smoke).

usage() {
  cat >&2 <<'EOF'
Usage:
  smoke-hosted-runtime.sh <base_url> [run_id]

Env (optional):
  OUT_DIR=/path/to/out
  CURL_TIMEOUT_SECS=12
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

BASE_URL_RAW="${1:-}"
RUN_ID="${2:-}"

if [ -z "${BASE_URL_RAW:-}" ]; then
  echo "Missing <base_url>" >&2
  usage
  exit 2
fi

# Repo root (this script lives in projects/security-questionnaire-autopilot/scripts).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HELPER="$ROOT/projects/security-questionnaire-autopilot/scripts/print-hosted-supabase-env-setup-help.sh"

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "jq"

normalize_url() {
  local u="$1"
  u="$(printf '%s' "$u" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\1#')"
  u="${u%/}"
  printf '%s' "$u"
}

BASE_URL="$(normalize_url "$BASE_URL_RAW")"
OUT_DIR="${OUT_DIR:-/tmp/hosted-runtime-smoke}"
T="${CURL_TIMEOUT_SECS:-12}"
mkdir -p "$OUT_DIR"

ENV_HEALTH_OUT="$OUT_DIR/env-health.json"
SUPABASE_HEALTH_OUT="$OUT_DIR/supabase-health.json"
DB_EVIDENCE_OUT="$OUT_DIR/db-evidence.json"
SUMMARY_OUT="$OUT_DIR/smoke-summary.json"

env_code="$(curl -sS -m "$T" -o "$ENV_HEALTH_OUT" -w "%{http_code}" "$BASE_URL/api/workflow/env-health" || echo "000")"
if [ "$env_code" != "200" ]; then
  echo "env-health failed (HTTP $env_code): $BASE_URL/api/workflow/env-health" >&2
  cat "$ENV_HEALTH_OUT" >&2 || true
  exit 2
fi
jq -e '.ok == true' "$ENV_HEALTH_OUT" >/dev/null
if ! jq -e '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$ENV_HEALTH_OUT" >/dev/null 2>&1; then
  echo "Hosted runtime is missing required Supabase env vars." >&2
  echo "Expected: NEXT_PUBLIC_SUPABASE_URL=true and SUPABASE_SERVICE_ROLE_KEY=true" >&2
  jq . "$ENV_HEALTH_OUT" >&2 || true
  if [ -x "$HELPER" ]; then
    "$HELPER" "$BASE_URL" || true
  else
    echo "See: docs/devops/cycle-005-hosted-runtime-env-vars.md" >&2
  fi
  exit 2
fi

sup_code="$(curl -sS -m "$T" -o "$SUPABASE_HEALTH_OUT" -w "%{http_code}" "$BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" || echo "000")"
if [ "$sup_code" != "200" ]; then
  echo "supabase-health failed (HTTP $sup_code): $BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" >&2
  cat "$SUPABASE_HEALTH_OUT" >&2 || true
  exit 2
fi
jq -e '.ok == true' "$SUPABASE_HEALTH_OUT" >/dev/null

db_code=""
db_ok="not_checked"
if [ -n "${RUN_ID:-}" ]; then
  db_code="$(curl -sS -m "$T" -o "$DB_EVIDENCE_OUT" -w "%{http_code}" \
    -H "content-type: application/json" \
    -d "{\"runId\":\"$RUN_ID\"}" \
    "$BASE_URL/api/workflow/db-evidence" || echo "000")"
  if [ "$db_code" != "200" ]; then
    echo "db-evidence failed (HTTP $db_code): $BASE_URL/api/workflow/db-evidence (runId=$RUN_ID)" >&2
    cat "$DB_EVIDENCE_OUT" >&2 || true
    exit 2
  fi
  jq -e '.ok == true' "$DB_EVIDENCE_OUT" >/dev/null
  jq -e --arg rid "$RUN_ID" '.runId == $rid' "$DB_EVIDENCE_OUT" >/dev/null
  db_ok="true"
else
  rm -f "$DB_EVIDENCE_OUT" 2>/dev/null || true
fi

schema_expected="$(jq -r '.schema.expected_schema_bundle_id // empty' "$SUPABASE_HEALTH_OUT" 2>/dev/null || true)"
schema_actual="$(jq -r '.schema.actual_schema_bundle_id // empty' "$SUPABASE_HEALTH_OUT" 2>/dev/null || true)"

jq -n \
  --arg base_url "$BASE_URL" \
  --arg run_id "${RUN_ID:-}" \
  --arg env_health "$ENV_HEALTH_OUT" \
  --arg supabase_health "$SUPABASE_HEALTH_OUT" \
  --arg db_evidence "${DB_EVIDENCE_OUT:-}" \
  --arg env_health_http "$env_code" \
  --arg supabase_health_http "$sup_code" \
  --arg db_evidence_http "${db_code:-}" \
  --arg db_ok "$db_ok" \
  --arg schema_expected "$schema_expected" \
  --arg schema_actual "$schema_actual" \
  '{
    ok: true,
    base_url: $base_url,
    run_id: ($run_id | select(length > 0) // null),
    http: {
      env_health: ($env_health_http | tonumber),
      supabase_health: ($supabase_health_http | tonumber),
      db_evidence: (if ($db_evidence_http | length) > 0 then ($db_evidence_http | tonumber) else null end)
    },
    checks: {
      env_health: true,
      supabase_health: true,
      db_evidence: (if $db_ok == "true" then true else "not_checked" end)
    },
    schema: {
      expected_schema_bundle_id: ($schema_expected | select(length > 0) // null),
      actual_schema_bundle_id: ($schema_actual | select(length > 0) // null)
    },
    artifacts: {
      env_health: $env_health,
      supabase_health: $supabase_health,
      db_evidence: (if ($run_id | length) > 0 then $db_evidence else null end)
    }
  }' > "$SUMMARY_OUT"

printf '%s\n' "$SUMMARY_OUT"
