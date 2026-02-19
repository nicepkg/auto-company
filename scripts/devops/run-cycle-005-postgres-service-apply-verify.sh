#!/usr/bin/env bash
set -euo pipefail

# Dispatch and capture evidence for:
#   .github/workflows/cycle-005-postgres-service-apply-verify.yml
#
# This workflow validates the Cycle 005 SQL bundle against a vanilla Postgres
# service container (no Supabase Management API, no Supabase secrets).

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-postgres-service-apply-verify.sh [flags]

Flags:
  --repo OWNER/REPO   (default: inferred via gh or git remote)
  --ref REF           optional ref for workflow dispatch
  --sql-bundle PATH   (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --no-watch          dispatch only; do not wait and do not download artifacts (prints run id)
  --run-id ID         skip dispatch; only download artifacts for an existing run
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

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO=""
REF=""
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
NO_WATCH="0"
RUN_ID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --no-watch) NO_WATCH="1"; shift 1 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -n "${RUN_ID:-}" ]; then
  "$ROOT/scripts/devops/gha-run-fetch-artifacts.sh" ${REPO:+--repo "$REPO"} --run-id "$RUN_ID" --artifact-name "cycle-005-postgres-service-apply-verify"
  exit 0
fi

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

dispatch_args=(
  "$ROOT/scripts/devops/gha-workflow-dispatch.sh"
  --repo "$REPO"
  --workflow "cycle-005-postgres-service-apply-verify.yml"
  --sql-bundle "$SQL_BUNDLE"
)
if [ -n "${REF:-}" ]; then
  dispatch_args+=(--ref "$REF")
fi

RUN_ID="$("${dispatch_args[@]}")"
echo "Run id: $RUN_ID" >&2

if [ "$NO_WATCH" = "1" ]; then
  cat >&2 <<EOF
Not watching or downloading artifacts (--no-watch).
To fetch artifacts later:
  scripts/devops/run-cycle-005-postgres-service-apply-verify.sh --repo "$REPO" --run-id "$RUN_ID"
EOF
  exit 0
fi

echo "Watching run (exit status reflects conclusion): gh run watch \"$RUN_ID\" -R \"$REPO\" --exit-status" >&2
watch_rc=0
gh run watch -R "$REPO" "$RUN_ID" --exit-status || watch_rc="$?"

# Always attempt artifact download/evidence capture even on failed runs.
"$ROOT/scripts/devops/gha-run-fetch-artifacts.sh" --repo "$REPO" --run-id "$RUN_ID" --artifact-name "cycle-005-postgres-service-apply-verify"

echo "Evidence captured. See docs/devops/evidence/ for extracted artifacts (supabase-verify-run-$RUN_ID.json)." >&2

if [ "${watch_rc:-0}" -ne 0 ]; then
  echo "WARNING: GitHub Actions run concluded non-success (watch exit code: $watch_rc)." >&2
  exit "$watch_rc"
fi

