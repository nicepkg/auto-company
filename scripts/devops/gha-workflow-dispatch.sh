#!/usr/bin/env bash
set -euo pipefail

# Dispatch a workflow and resolve the resulting run id, writing JSON evidence.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/gha-workflow-dispatch.sh [flags]

Flags:
  --repo OWNER/REPO          (default: inferred via gh or git remote)
  --workflow FILE.yml        (default: cycle-005-supabase-provision-apply-verify.yml)
  --ref REF                  optional git ref (branch/tag/SHA) to run workflow from
  --supabase-project-name N  (default: security-questionnaire-autopilot-cycle-005)
  --reuse-existing true|false (default: true)
  --sql-bundle PATH          (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --out PATH                 (default: docs/devops/evidence/workflow-dispatch-<ts>.json)
  --print-run-id             print run id to stdout (default: true)

Auth:
  - Recommended: export GH_TOKEN="..." and use gh CLI.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID_DIR="$ROOT/docs/devops/evidence"
mkdir -p "$EVID_DIR"

REPO=""
WORKFLOW="cycle-005-supabase-provision-apply-verify.yml"
REF=""
SUPABASE_PROJECT_NAME="security-questionnaire-autopilot-cycle-005"
REUSE_EXISTING="true"
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
OUT=""
PRINT_RUN_ID="1"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --workflow) WORKFLOW="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --supabase-project-name) SUPABASE_PROJECT_NAME="${2:-}"; shift 2 ;;
    --reuse-existing) REUSE_EXISTING="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --print-run-id) PRINT_RUN_ID="1"; shift 1 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_bin gh
require_bin jq

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPO:-}" ]; then
  REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#\\.git$##' | sed -E 's#.*github\\.com[:/]+([^/]+/[^/]+)$#\\1#' || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
if [ -z "${OUT:-}" ]; then
  OUT="$EVID_DIR/workflow-dispatch-$ts.json"
fi

start="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

args=(workflow run "$WORKFLOW" -R "$REPO"
  -f "supabase_project_name=$SUPABASE_PROJECT_NAME"
  -f "reuse_existing=$REUSE_EXISTING"
  -f "sql_bundle=$SQL_BUNDLE"
)
if [ -n "${REF:-}" ]; then
  args+=(--ref "$REF")
fi

gh "${args[@]}" >/dev/null

# Resolve run id by polling the workflow runs API (workflows/<file>/runs).
run_id=""
run_url=""
status=""
conclusion=""
created_at=""

for _ in $(seq 1 30); do
  raw="$(gh api "repos/${REPO}/actions/workflows/${WORKFLOW}/runs?event=workflow_dispatch&per_page=10" 2>/dev/null || true)"
  if [ -n "${raw:-}" ]; then
    run_id="$(jq -r --arg start "$start" '.workflow_runs | map(select(.created_at >= $start)) | .[0].id // empty' <<<"$raw")"
    if [ -n "${run_id:-}" ]; then
      run_url="$(jq -r --argjson id "$run_id" '.workflow_runs | map(select(.id == $id)) | .[0].html_url // empty' <<<"$raw")"
      status="$(jq -r --argjson id "$run_id" '.workflow_runs | map(select(.id == $id)) | .[0].status // empty' <<<"$raw")"
      conclusion="$(jq -r --argjson id "$run_id" '.workflow_runs | map(select(.id == $id)) | .[0].conclusion // empty' <<<"$raw")"
      created_at="$(jq -r --argjson id "$run_id" '.workflow_runs | map(select(.id == $id)) | .[0].created_at // empty' <<<"$raw")"
      break
    fi
  fi
  sleep 2
done

if [ -z "${run_id:-}" ]; then
  jq -n \
    --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg repo "$REPO" \
    --arg workflow "$WORKFLOW" \
    --arg ref "$REF" \
    --arg start "$start" \
    --arg supabase_project_name "$SUPABASE_PROJECT_NAME" \
    --arg reuse_existing "$REUSE_EXISTING" \
    --arg sql_bundle "$SQL_BUNDLE" \
    '{checked_at_utc:$checked_at_utc, repo:$repo, workflow:$workflow, ref:$ref, dispatch_started_at_utc:$start, inputs:{supabase_project_name:$supabase_project_name, reuse_existing:$reuse_existing, sql_bundle:$sql_bundle}, error:"Dispatched, but could not resolve run id via API within timeout."}' \
    >"$OUT"
  echo "ERROR: dispatched workflow but could not resolve run id. Evidence: $OUT" >&2
  echo "Manual fallback:" >&2
  echo "  gh run list -R \"$REPO\" --workflow \"$WORKFLOW\" -L 5" >&2
  exit 2
fi

jq -n \
  --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg repo "$REPO" \
  --arg workflow "$WORKFLOW" \
  --arg ref "$REF" \
  --arg start "$start" \
  --arg run_id "$run_id" \
  --arg run_url "$run_url" \
  --arg status "$status" \
  --arg conclusion "$conclusion" \
  --arg created_at "$created_at" \
  --arg supabase_project_name "$SUPABASE_PROJECT_NAME" \
  --arg reuse_existing "$REUSE_EXISTING" \
  --arg sql_bundle "$SQL_BUNDLE" \
  '{checked_at_utc:$checked_at_utc, repo:$repo, workflow:$workflow, ref:$ref, dispatch_started_at_utc:$start, run:{id:($run_id|tonumber), url:$run_url, status:$status, conclusion:$conclusion, created_at_utc:$created_at}, inputs:{supabase_project_name:$supabase_project_name, reuse_existing:$reuse_existing, sql_bundle:$sql_bundle}}' \
  >"$OUT"

echo "Dispatched: $run_url" >&2
echo "Evidence: $OUT" >&2

if [ "$PRINT_RUN_ID" = "1" ]; then
  printf '%s\n' "$run_id"
fi

