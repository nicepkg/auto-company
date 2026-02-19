#!/usr/bin/env bash
set -euo pipefail

# Provision a Supabase project via the Supabase Management API, without supabase/psql CLIs.
# This script intentionally does NOT print secrets (token/db password/api keys).
#
# Requires (env):
#   SUPABASE_ACCESS_TOKEN
#   SUPABASE_ORG_SLUG
#   SUPABASE_PROJECT_NAME
#   SUPABASE_DB_PASSWORD
#
# Optional (env):
#   SUPABASE_REGION            (legacy; may be ignored/deprecated by Supabase; safe to omit)
#   SUPABASE_REGION_SELECTION_JSON (recommended; JSON object, e.g. {"type":"smartGroup","code":"americas"})
#   SUPABASE_MGMT_API_BASE     (default: https://api.supabase.com)
#   SUPABASE_PROVISION_TIMEOUT_SECONDS (default: 1200)
#   SUPABASE_ALLOW_REUSE_EXISTING=true|false (default: true)
#   SUPABASE_PROMPT_FOR_MISSING=1 (interactive fallback for local use; not for CI)
#
# Optional (flags):
#   --out <path>   Write sanitized JSON summary to an explicit path (default: docs/devops/)
#   --print-ref    Print only the project ref to stdout and exit 0.
#   --quiet        Suppress human-readable stderr summary.
#
# Output:
#   Writes a sanitized JSON summary (no secrets) to docs/devops/.
#
# Notes:
# - Applying migrations/seed is a separate step (see docs/operations runbook).
# - If your org has SSO/SCIM restrictions, the access token must have project create permissions.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

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

prompt_if_missing() {
  local name="$1"
  local prompt="$2"
  local secret="${3:-0}"
  if [ -n "${!name:-}" ]; then
    return 0
  fi
  if [ -z "${SUPABASE_PROMPT_FOR_MISSING:-}" ] || [ "${SUPABASE_PROMPT_FOR_MISSING:-}" = "0" ]; then
    echo "Missing env var: $name" >&2
    echo "Tip: set SUPABASE_PROMPT_FOR_MISSING=1 to be prompted interactively." >&2
    exit 2
  fi
  if [ "$secret" = "1" ]; then
    read -r -s -p "$prompt: " "$name" </dev/tty
    echo "" >/dev/tty
  else
    read -r -p "$prompt: " "$name" </dev/tty
  fi
  if [ -z "${!name:-}" ]; then
    echo "Missing required value for: $name" >&2
    exit 2
  fi
  export "$name"
}

require_bin "curl"
require_bin "jq"

prompt_if_missing "SUPABASE_ACCESS_TOKEN" "Supabase access token (SUPABASE_ACCESS_TOKEN)" 1
prompt_if_missing "SUPABASE_ORG_SLUG" "Supabase org slug (SUPABASE_ORG_SLUG)" 0
prompt_if_missing "SUPABASE_PROJECT_NAME" "Supabase project name (SUPABASE_PROJECT_NAME)" 0
prompt_if_missing "SUPABASE_DB_PASSWORD" "Supabase DB password (SUPABASE_DB_PASSWORD)" 1

API_BASE="${SUPABASE_MGMT_API_BASE:-https://api.supabase.com}"
REGION="${SUPABASE_REGION:-}"
REGION_SEL_JSON="${SUPABASE_REGION_SELECTION_JSON:-}"
TIMEOUT_S="${SUPABASE_PROVISION_TIMEOUT_SECONDS:-1200}"
ALLOW_REUSE="${SUPABASE_ALLOW_REUSE_EXISTING:-true}"

PRINT_REF="0"
QUIET="0"
OUT_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --out)
      OUT_OVERRIDE="${2:-}"
      if [ -z "$OUT_OVERRIDE" ]; then
        echo "Missing value for --out <path>" >&2
        exit 2
      fi
      shift 2
      ;;
    --print-ref)
      PRINT_REF="1"
      shift 1
      ;;
    --quiet)
      QUIET="1"
      shift 1
      ;;
    *)
      echo "Unknown arg: ${1:-}" >&2
      exit 2
      ;;
  esac
done

ts_utc="$(date -u +"%Y%m%dT%H%M%SZ")"
OUT_DIR="$ROOT/docs/devops"
mkdir -p "$OUT_DIR"
OUT_JSON_DEFAULT="$OUT_DIR/cycle-016-supabase-provision-${ts_utc}.json"
OUT_JSON="${OUT_OVERRIDE:-$OUT_JSON_DEFAULT}"

# Temp files contain request payloads; keep them non-world-readable.
umask 077
tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

req_json="$tmp_dir/create.json"
res_json="$tmp_dir/create.res.json"
poll_json="$tmp_dir/poll.res.json"
list_json="$tmp_dir/list.res.json"

sanitize_json_to_stderr() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return 0
  fi
  jq -c '
    def redact:
      if type == "object" then
        with_entries(
          if (.key | test("key|secret|token|pass|password|jwt|apikey"; "i"))
          then .value = "***REDACTED***"
          else . end
        )
      else . end;
    walk(redact)
  ' "$file" 2>/dev/null | head -c 1200 >&2 || true
  echo "" >&2
}

find_existing_ref() {
  # Try to reuse an existing project with the same name (best-effort, avoids duplicates).
  # If multiple matches exist, fail fast to prevent ambiguity.
  local code existing_count existing_ref
  code="$(curl -sS -o "$list_json" -w "%{http_code}" \
    -X GET "$API_BASE/v1/projects" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" || true)"
  code="${code:-000}"
  if [ "$code" != "200" ]; then
    return 0
  fi
  existing_count="$(jq -r --arg name "$SUPABASE_PROJECT_NAME" --arg org "$SUPABASE_ORG_SLUG" '
    [ .[]?
      | select((.name // "") == $name)
      | select((.organization_slug // .organization?.slug // "") == $org or $org == "")
    ] | length
  ' "$list_json" 2>/dev/null || echo "0")"
  if [ "${existing_count:-0}" = "1" ]; then
    existing_ref="$(jq -r --arg name "$SUPABASE_PROJECT_NAME" --arg org "$SUPABASE_ORG_SLUG" '
      [ .[]?
        | select((.name // "") == $name)
        | select((.organization_slug // .organization?.slug // "") == $org or $org == "")
        | (.ref // .project_ref // empty)
      ][0] // empty
    ' "$list_json" 2>/dev/null || true)"
    if [ -n "$existing_ref" ] && [ "$existing_ref" != "null" ]; then
      printf '%s' "$existing_ref"
    fi
    return 0
  fi
  if [ "${existing_count:-0}" != "0" ]; then
    echo "Multiple Supabase projects found matching name=$SUPABASE_PROJECT_NAME org_slug=$SUPABASE_ORG_SLUG. Refuse to pick arbitrarily." >&2
    exit 2
  fi
  return 0
}

ref=""
if [ "$ALLOW_REUSE" = "1" ] || [ "$ALLOW_REUSE" = "true" ] || [ "$ALLOW_REUSE" = "yes" ]; then
  ref="$(find_existing_ref || true)"
fi

if [ -z "$ref" ]; then
  # Build request body safely with jq to avoid quoting bugs.
  jq -n \
    --arg name "$SUPABASE_PROJECT_NAME" \
    --arg org "$SUPABASE_ORG_SLUG" \
    --arg db_pass "$SUPABASE_DB_PASSWORD" \
    --arg region "$REGION" \
    --arg region_sel "$REGION_SEL_JSON" \
    '{
      name: $name,
      organization_slug: $org,
      db_pass: $db_pass
    }
    + ( ($region | length) > 0 ? { region: $region } : {} )
    + ( ($region_sel | length) > 0 ? { region_selection: ($region_sel | fromjson) } : {} )
    ' >"$req_json"

  code="$(curl -sS -o "$res_json" -w "%{http_code}" \
    -X POST "$API_BASE/v1/projects" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary @"$req_json" || true)"
  code="${code:-000}"

  if [ "$code" != "200" ] && [ "$code" != "201" ]; then
    err="$(jq -r '.message // .error // .msg // .hint // empty' "$res_json" 2>/dev/null || true)"
    echo "Supabase project create failed (HTTP $code). ${err:-}" >&2
    echo "Response (sanitized):" >&2
    sanitize_json_to_stderr "$res_json"
    exit 2
  fi

  ref="$(jq -r '.ref // .project_ref // empty' "$res_json" 2>/dev/null || true)"
  if [ -z "$ref" ] || [ "$ref" = "null" ]; then
    echo "Supabase project create response did not include a project ref (.ref). Cannot continue." >&2
    echo "Response (sanitized):" >&2
    sanitize_json_to_stderr "$res_json"
    exit 2
  fi
fi

deadline="$(( $(date +%s) + TIMEOUT_S ))"
status=""

while :; do
  now="$(date +%s)"
  if [ "$now" -ge "$deadline" ]; then
    echo "Timed out waiting for Supabase project to become ACTIVE (ref=$ref, last_status=${status:-unknown})." >&2
    break
  fi

poll_code="$(curl -sS -o "$poll_json" -w "%{http_code}" \
    -X GET "$API_BASE/v1/projects/$ref" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" || true)"
  poll_code="${poll_code:-000}"

  if [ "$poll_code" = "200" ]; then
    status="$(jq -r '.status // empty' "$poll_json" 2>/dev/null || true)"
    # Treat any ACTIVE* status as ready. Supabase commonly uses ACTIVE_HEALTHY.
    if printf '%s' "$status" | grep -qE '^ACTIVE'; then
      break
    fi
  else
    # Keep polling; transient 404s can happen immediately after create.
    status="HTTP_${poll_code}"
  fi

  sleep 10
done

project_url="https://${ref}.supabase.co"
db_host="db.${ref}.supabase.co"

# Flag: print only the project ref to stdout and exit (no JSON written).
if [ "$PRINT_REF" = "1" ]; then
  printf '%s\n' "$ref"
  exit 0
fi

# Write sanitized summary (no secrets).
jq -n \
  --arg created_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg ref "$ref" \
  --arg name "$SUPABASE_PROJECT_NAME" \
  --arg org "$SUPABASE_ORG_SLUG" \
  --arg status "$status" \
  --arg project_url "$project_url" \
  --arg db_host "$db_host" \
  --arg region "$REGION" \
  --arg region_sel "$REGION_SEL_JSON" \
  '{
    created_at_utc: $created_at_utc,
    ref: $ref,
    name: $name,
    organization_slug: $org,
    status: ($status | if . == "" then null else . end),
    project_url: $project_url,
    db_host: $db_host,
    region: ($region | if . == "" then null else . end),
    region_selection_json: ($region_sel | if . == "" then null else . end),
    next: {
      apply_sql_bundle: "projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql",
      required_hosted_env_vars: ["NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]
    }
  }' >"$OUT_JSON"

# Safe CI outputs (no secrets).
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "supabase_project_ref=$ref"
    echo "supabase_project_url=$project_url"
    echo "supabase_db_host=$db_host"
    echo "summary_json=$OUT_JSON"
  } >>"$GITHUB_OUTPUT"
fi

# Machine-friendly (safe) outputs for CI parsing.
cat <<EOF
project_ref=$ref
project_url=$project_url
db_host=$db_host
status=${status:-unknown}
summary_json=$OUT_JSON
EOF

if [ "$QUIET" != "1" ]; then
  cat >&2 <<EOF
Provisioned (or reused) Supabase project.

ref=$ref
project_url=$project_url
db_host=$db_host
status=${status:-unknown}
summary_json=$OUT_JSON

Next (no secrets printed):
  - Apply SQL bundle: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
  - Set hosted runtime env:
      NEXT_PUBLIC_SUPABASE_URL="$project_url"
      SUPABASE_SERVICE_ROLE_KEY="<retrieve from Supabase Dashboard -> Settings -> API>"
EOF
fi
