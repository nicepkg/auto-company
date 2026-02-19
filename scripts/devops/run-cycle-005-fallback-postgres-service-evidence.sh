#!/usr/bin/env bash
set -euo pipefail

# Cycle 005 deterministic fallback path:
# - Apply + verify the SQL bundle against a vanilla Postgres *GitHub Actions service container*
# - No Supabase Management API secrets required
# - Store all evidence under docs/devops-hightower/ (role-owned artifacts)

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh [flags]

Flags:
  --repo OWNER/REPO   (default: inferred via gh or git remote)
  --ref REF           optional ref for workflow dispatch
  --sql-bundle PATH   (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --no-watch          dispatch only; do not wait and do not download artifacts (prints run id)
  --run-id ID         skip dispatch; only download artifacts for an existing run
  --out-dir DIR       (default: docs/devops-hightower/cycle-005/postgres-service-apply-verify)

Outputs (under --out-dir):
  evidence/
    supabase-verify-run-<runid>.json
    artifact-fetch-<ts>-run-<runid>.json
    artifacts/run-<runid>/...
  latest/
    supabase-verify.json          (copy of supabase-verify-run-<runid>.json)
    artifact-fetch.json           (copy of artifact-fetch-<ts>-run-<runid>.json)
    run.json                      (small pointer manifest)
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

require_bin gh
require_bin jq

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO=""
REF=""
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
NO_WATCH="0"
RUN_ID=""
OUT_DIR="$ROOT/docs/devops-hightower/cycle-005/postgres-service-apply-verify"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --no-watch) NO_WATCH="1"; shift 1 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

EVID_DIR="$OUT_DIR/evidence"
LATEST_DIR="$OUT_DIR/latest"
mkdir -p "$EVID_DIR" "$LATEST_DIR"

infer_repo() {
  if [ -n "${REPO:-}" ]; then
    return 0
  fi
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  if [ -z "${REPO:-}" ]; then
    REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#\\.git$##' | sed -E 's#.*github\\.com[:/]+([^/]+/[^/]+)$#\\1#' || true)"
  fi
  if [ -z "${REPO:-}" ]; then
    echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
    exit 2
  fi
}

ensure_workflow_exists_on_remote() {
  # GitHub only exposes workflow_dispatch targets that exist on the repo's default branch.
  # If this workflow file isn't merged, dispatch will 404.
  local tmp
  tmp="$(mktemp)"
  if gh api "repos/${REPO}/actions/workflows/cycle-005-postgres-service-apply-verify.yml" >/dev/null 2>"$tmp"; then
    rm -f "$tmp" >/dev/null 2>&1 || true
    return 0
  fi

  local ts
  ts="$(date -u +"%Y%m%dT%H%M%SZ")"
  local out="$OUT_DIR/workflow-missing-on-remote-$ts.json"
  local err
  err="$(tail -c 2000 "$tmp" 2>/dev/null || true)"
  rm -f "$tmp" >/dev/null 2>&1 || true

  jq -n \
    --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg repo "$REPO" \
    --arg workflow "cycle-005-postgres-service-apply-verify.yml" \
    --arg gh_error "$err" \
    '{checked_at_utc:$checked_at_utc, repo:$repo, workflow:$workflow, error:"Workflow not found on remote default branch; cannot dispatch.", gh_error:$gh_error, note:"Merge .github/workflows/cycle-005-postgres-service-apply-verify.yml to the default branch, then re-run this script."}' \
    >"$out"

  echo "ERROR: remote workflow missing; cannot dispatch workflow_dispatch." >&2
  echo "Evidence: $out" >&2
  echo "Fix: merge .github/workflows/cycle-005-postgres-service-apply-verify.yml to ${REPO}'s default branch." >&2
  exit 2
}

fetch_only() {
  infer_repo
  "$ROOT/scripts/devops/gha-run-fetch-artifacts.sh" \
    --repo "$REPO" \
    --run-id "$RUN_ID" \
    --artifact-name "cycle-005-postgres-service-apply-verify" \
    --evidence-dir "$EVID_DIR"

  local verify_src="$EVID_DIR/supabase-verify-run-$RUN_ID.json"
  local fetch_manifest_src
  fetch_manifest_src="$(ls -1t "$EVID_DIR"/artifact-fetch-*-run-"$RUN_ID".json 2>/dev/null | head -n 1 || true)"

  if [ -f "$verify_src" ]; then
    cp "$verify_src" "$LATEST_DIR/supabase-verify.json"
  fi
  if [ -n "${fetch_manifest_src:-}" ] && [ -f "$fetch_manifest_src" ]; then
    cp "$fetch_manifest_src" "$LATEST_DIR/artifact-fetch.json"
  fi

  jq -n \
    --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg repo "$REPO" \
    --arg run_id "$RUN_ID" \
    --arg workflow "cycle-005-postgres-service-apply-verify.yml" \
    --arg sql_bundle "$SQL_BUNDLE" \
    --arg evidence_dir "$EVID_DIR" \
    --arg latest_dir "$LATEST_DIR" \
    '{checked_at_utc:$checked_at_utc, repo:$repo, workflow:$workflow, run_id:($run_id|tonumber), inputs:{sql_bundle:$sql_bundle}, paths:{evidence_dir:$evidence_dir, latest_dir:$latest_dir}}' \
    >"$LATEST_DIR/run.json"

  echo "Evidence (latest): $LATEST_DIR/supabase-verify.json" >&2
  echo "Pointer: $LATEST_DIR/run.json" >&2
}

if [ -n "${RUN_ID:-}" ]; then
  fetch_only
  exit 0
fi

infer_repo
ensure_workflow_exists_on_remote

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
dispatch_out="$OUT_DIR/workflow-dispatch-$ts.json"

dispatch_args=(
  "$ROOT/scripts/devops/gha-workflow-dispatch.sh"
  --repo "$REPO"
  --workflow "cycle-005-postgres-service-apply-verify.yml"
  --sql-bundle "$SQL_BUNDLE"
  --out "$dispatch_out"
)
if [ -n "${REF:-}" ]; then
  dispatch_args+=(--ref "$REF")
fi

RUN_ID="$("${dispatch_args[@]}")"
echo "Run id: $RUN_ID" >&2

if [ "$NO_WATCH" = "1" ]; then
  cat >&2 <<EOF
Not watching or downloading artifacts (--no-watch).
To fetch evidence later:
  scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh --repo "$REPO" --run-id "$RUN_ID" --out-dir "$OUT_DIR"
EOF
  exit 0
fi

echo "Watching run (exit status reflects conclusion): gh run watch \"$RUN_ID\" -R \"$REPO\" --exit-status" >&2
watch_rc=0
gh run watch -R "$REPO" "$RUN_ID" --exit-status || watch_rc="$?"

# Always attempt artifact download/evidence capture even on failed runs.
fetch_only

if [ "${watch_rc:-0}" -ne 0 ]; then
  echo "WARNING: GitHub Actions run concluded non-success (watch exit code: $watch_rc)." >&2
  exit "$watch_rc"
fi
