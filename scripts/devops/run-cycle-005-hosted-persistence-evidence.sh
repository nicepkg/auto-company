#!/usr/bin/env bash
set -euo pipefail

# Operator wrapper: preflight repo vars/secrets then run Cycle 005 evidence workflow via gh.
#
# Why this exists:
# - Reduce wrong-BASE_URL runs by standardizing candidate handling.
# - Fail fast if required repo variable/secrets are missing.
#
# Requires:
# - gh CLI authenticated
# - permission to read/set repo Actions variables and read repo secrets list

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-hosted-persistence-evidence.sh [flags]

Flags:
  --repo OWNER/REPO            (default: inferred from git remote via gh)
  --candidates "u1 u2 ..."     Set/override HOSTED_WORKFLOW_BASE_URL_CANDIDATES for this run (also sets repo variable if --set-variable)
  --candidates-file PATH       Read candidates from file (one per line; comments allowed)
  --set-variable               Write candidates into repo variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES
  --base-url "u1 u2 ..."       Pass candidates directly to workflow_dispatch input base_url (does not persist)
  --run-id RUN_ID              Explicit run id (default: workflow generates)
  --skip-sql-apply true|false  (default: true)
  --sql-bundle PATH            (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --require-fallback-secrets   Enforce NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY secrets exist (off by default)
  --no-local-probe             Skip best-effort local probing of candidates (workflow will still probe)
  --seed-run-id RUN_ID         Seed run_id to use for local db-evidence smoke check (default: pilot-001-live-2026-02-13)
  --no-local-smoke             Skip local supabase-health + db-evidence smoke checks
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

REPO=""
CANDIDATES=""
CANDIDATES_FILE=""
SET_VARIABLE="0"
BASE_URL_INPUT=""
RUN_ID=""
SKIP_SQL_APPLY="true"
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
REQUIRE_FALLBACK_SECRETS="0"
LOCAL_PROBE="1"
SEED_RUN_ID="pilot-001-live-2026-02-13"
LOCAL_SMOKE="1"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --candidates) CANDIDATES="${2:-}"; shift 2 ;;
    --candidates-file) CANDIDATES_FILE="${2:-}"; shift 2 ;;
    --set-variable) SET_VARIABLE="1"; shift 1 ;;
    --base-url) BASE_URL_INPUT="${2:-}"; shift 2 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --skip-sql-apply) SKIP_SQL_APPLY="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --require-fallback-secrets) REQUIRE_FALLBACK_SECRETS="1"; shift 1 ;;
    --no-local-probe) LOCAL_PROBE="0"; shift 1 ;;
    --seed-run-id) SEED_RUN_ID="${2:-}"; shift 2 ;;
    --no-local-smoke) LOCAL_SMOKE="0"; shift 1 ;;
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

require_bin "gh"

gh auth status -h github.com >/dev/null

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FORMAT="$ROOT/projects/security-questionnaire-autopilot/scripts/format-base-url-candidates.sh"
DISCOVER="$ROOT/projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh"

if [ -n "${CANDIDATES_FILE:-}" ]; then
  if [ ! -f "$CANDIDATES_FILE" ]; then
    echo "Candidates file not found: $CANDIDATES_FILE" >&2
    exit 2
  fi
  CANDIDATES="$("$FORMAT" "$CANDIDATES_FILE")"
fi

if [ "${SET_VARIABLE}" = "1" ]; then
  if [ -z "${CANDIDATES:-}" ]; then
    echo "--set-variable requires --candidates or --candidates-file" >&2
    exit 2
  fi
  gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "$CANDIDATES" >/dev/null
fi

get_var_value() {
  local name="$1"
  gh api "repos/${REPO}/actions/variables/${name}" -q '.value' 2>/dev/null || true
}

have_secret() {
  local name="$1"
  gh secret list -R "$REPO" --app actions --json name -q \
    ".[] | select(.name==\"$name\") | .name" 2>/dev/null | head -n 1
}

if [ "${SKIP_SQL_APPLY}" != "true" ] && [ "${SKIP_SQL_APPLY}" != "false" ]; then
  echo "Invalid --skip-sql-apply value: ${SKIP_SQL_APPLY} (expected true|false)" >&2
  exit 2
fi

if [ "${SKIP_SQL_APPLY}" = "false" ]; then
  if [ -z "$(have_secret "SUPABASE_DB_URL" || true)" ]; then
    echo "Missing required secret: SUPABASE_DB_URL (required when --skip-sql-apply=false)" >&2
    exit 2
  fi
fi

if [ "${REQUIRE_FALLBACK_SECRETS}" = "1" ]; then
  for s in NEXT_PUBLIC_SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY; do
    if [ -z "$(have_secret "$s" || true)" ]; then
      echo "Missing required fallback secret: $s" >&2
      exit 2
    fi
  done
fi

BASE_URL_FIELD=""
BASE_URL_SOURCE=""
if [ -n "${BASE_URL_INPUT:-}" ]; then
  BASE_URL_FIELD="$BASE_URL_INPUT"
  BASE_URL_SOURCE="--base-url"
elif [ -n "${CANDIDATES:-}" ]; then
  BASE_URL_FIELD="$CANDIDATES"
  BASE_URL_SOURCE="--candidates/--candidates-file"
else
  v="$(get_var_value "HOSTED_WORKFLOW_BASE_URL_CANDIDATES")"
  if [ -n "$v" ]; then
    BASE_URL_FIELD="$v"
    BASE_URL_SOURCE="repo variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES"
  fi
fi

if [ -z "${BASE_URL_FIELD:-}" ]; then
  echo "Missing BASE_URL candidates." >&2
  echo "" >&2
  echo "Do one of:" >&2
  echo "  1) Set repo variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES:" >&2
  echo "     gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R \"$REPO\" --body \"https://<candidate1> https://<candidate2>\"" >&2
  echo "  2) Or run this script with --base-url \"https://<candidate1> https://<candidate2>\"" >&2
  echo "  3) Or run this script with --candidates-file docs/devops/base-url-candidates.template.txt --set-variable" >&2
  exit 2
fi

echo "BASE_URL candidates source: ${BASE_URL_SOURCE:-unknown}" >&2
LOCAL_SELECTED_BASE_URL=""

if [ "${LOCAL_PROBE}" = "1" ] && command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  if selected="$("$DISCOVER" "$BASE_URL_FIELD" 2>/dev/null)"; then
    if [ -n "${selected:-}" ]; then
      echo "Locally selected BASE_URL: $selected" >&2
      BASE_URL_FIELD="$selected"
      LOCAL_SELECTED_BASE_URL="$selected"
    fi
  else
    echo "Warning: local BASE_URL probe failed; proceeding with workflow-side discovery." >&2
  fi
fi

if [ "${LOCAL_SMOKE}" = "1" ] && [ -n "${LOCAL_SELECTED_BASE_URL:-}" ] && [ "${SKIP_SQL_APPLY}" = "true" ] && command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  base="${LOCAL_SELECTED_BASE_URL%/}"
  echo "Local smoke: GET ${base}/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" >&2
  tmp="$(mktemp)"
  code="$(curl -sS -m 12 -o "$tmp" -w "%{http_code}" "${base}/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" || echo "000")"
  if [ "$code" != "200" ] || ! jq -e '.ok == true' "$tmp" >/dev/null 2>&1; then
    cat "$tmp" >&2 || true
    rm -f "$tmp"
    echo "Local smoke failed: supabase-health is not healthy. This CI run will fail too." >&2
    exit 2
  fi
  rm -f "$tmp"

  echo "Local smoke: POST ${base}/api/workflow/db-evidence (runId=${SEED_RUN_ID})" >&2
  tmp="$(mktemp)"
  code="$(curl -sS -m 12 -o "$tmp" -w "%{http_code}" -X POST "${base}/api/workflow/db-evidence" -H 'content-type: application/json' -d "{\"runId\":\"${SEED_RUN_ID}\"}" || echo "000")"
  if [ "$code" != "200" ] || ! jq -e '.ok == true' "$tmp" >/dev/null 2>&1; then
    cat "$tmp" >&2 || true
    rm -f "$tmp"
    echo "Local smoke failed: db-evidence is not healthy. This CI run will fail too." >&2
    exit 2
  fi
  if ! jq -e --arg rid "${SEED_RUN_ID}" '.workflow_runs != null and (.workflow_runs.run_id == $rid or .workflow_runs.runId == $rid)' "$tmp" >/dev/null 2>&1; then
    cat "$tmp" >&2 || true
    rm -f "$tmp"
    echo "Local smoke failed: db-evidence did not include expected workflow_runs row for seed runId=${SEED_RUN_ID}." >&2
    exit 2
  fi
  rm -f "$tmp"
fi

require_fallback="$([ "${REQUIRE_FALLBACK_SECRETS}" = "1" ] && echo true || echo false)"
start_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

gh workflow run cycle-005-hosted-persistence-evidence.yml -R "$REPO" \
  -f base_url="${BASE_URL_FIELD}" \
  -f run_id="${RUN_ID}" \
  -f skip_sql_apply="${SKIP_SQL_APPLY}" \
  -f sql_bundle="${SQL_BUNDLE}" \
  -f require_fallback_supabase_secrets="${require_fallback}" >/dev/null

query="map(select(.createdAt >= \"$start_ts\")) | .[0].databaseId"
run_dbid="$(gh run list -R "$REPO" --workflow cycle-005-hosted-persistence-evidence.yml -L 10 --json databaseId,createdAt -q "$query" 2>/dev/null || true)"
if [ -z "${run_dbid:-}" ] || [ "${run_dbid:-}" = "null" ]; then
  run_dbid="$(gh run list -R "$REPO" --workflow cycle-005-hosted-persistence-evidence.yml -L 1 --json databaseId -q '.[0].databaseId')"
fi

run_url="$(gh run view -R "$REPO" "$run_dbid" --json htmlUrl -q '.htmlUrl' 2>/dev/null || true)"
echo "GHA run databaseId: $run_dbid"
if [ -n "${run_url:-}" ] && [ "${run_url:-}" != "null" ]; then
  echo "GHA run url: $run_url"
fi
echo "Watching run..."
gh run watch -R "$REPO" "$run_dbid" --exit-status

run_id="$(gh run view -R "$REPO" "$run_dbid" --json id -q '.id' 2>/dev/null || true)"
if [ -n "${run_id:-}" ] && [ "${run_id:-}" != "null" ]; then
  branch="cycle-005-hosted-persistence-evidence-${run_id}"
  pr_url="$(gh pr list -R "$REPO" --head "$branch" --state all --json url -q '.[0].url' 2>/dev/null || true)"
  if [ -n "${pr_url:-}" ] && [ "${pr_url:-}" != "null" ]; then
    echo "Evidence PR: $pr_url"
  else
    echo "No PR found yet for branch: $branch" >&2
  fi
fi
