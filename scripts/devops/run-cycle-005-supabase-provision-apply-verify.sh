#!/usr/bin/env bash
set -euo pipefail

# End-to-end operator wrapper:
# 1) verify required Actions secrets exist
# 2) optionally set missing secrets (prompts unless --non-interactive)
# 3) dispatch workflow
# 4) watch completion
# 5) download artifacts and extract supabase-verify.json into docs/devops/evidence/

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh [flags]

Flags:
  --repo OWNER/REPO             (default: inferred via gh or git remote)
  --ref REF                     optional ref for workflow dispatch
  --supabase-project-name NAME  (default: security-questionnaire-autopilot-cycle-005)
  --reuse-existing true|false   (default: true)
  --sql-bundle PATH             (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --set-missing-secrets         if required secrets are missing, prompt and set them via gh
  --non-interactive             used with --set-missing-secrets; requires env vars to be set (no prompting)
  --skip-secrets-check          dispatch even if secrets are missing (workflow should still upload safe evidence)
  --no-watch                    dispatch only; skip waiting for completion (still resolves run id)
  --run-id ID                   skip dispatch; only download artifacts for an existing run

Compat flags (aliases):
  --set-secrets                 alias for --set-missing-secrets
  --prompt-missing              no-op (interactive prompting is default when not using --non-interactive)

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

require_bin gh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID_DIR="$ROOT/docs/devops/evidence"
mkdir -p "$EVID_DIR"

REPO=""
REF=""
SUPABASE_PROJECT_NAME="security-questionnaire-autopilot-cycle-005"
REUSE_EXISTING="true"
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
SET_MISSING="0"
NON_INTERACTIVE="0"
SKIP_SECRETS_CHECK="0"
NO_WATCH="0"
RUN_ID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --supabase-project-name) SUPABASE_PROJECT_NAME="${2:-}"; shift 2 ;;
    --reuse-existing) REUSE_EXISTING="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --set-missing-secrets) SET_MISSING="1"; shift 1 ;;
    --set-secrets) SET_MISSING="1"; shift 1 ;;
    --non-interactive) NON_INTERACTIVE="1"; shift 1 ;;
    --prompt-missing) shift 1 ;; # interactive prompting is default
    --skip-secrets-check) SKIP_SECRETS_CHECK="1"; shift 1 ;;
    --no-watch) NO_WATCH="1"; shift 1 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -n "${RUN_ID:-}" ]; then
  "$ROOT/scripts/devops/gha-run-fetch-artifacts.sh" ${REPO:+--repo "$REPO"} --run-id "$RUN_ID"
  exit 0
fi

required="SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD"

if [ "$SKIP_SECRETS_CHECK" != "1" ] && ! "$ROOT/scripts/devops/gha-secrets-verify.sh" ${REPO:+--repo "$REPO"} --required "$required" >/dev/null 2>&1; then
  if [ "$SET_MISSING" != "1" ]; then
    echo "Required secrets missing. Run with --set-missing-secrets to set them, or set them in GitHub UI." >&2
    "$ROOT/scripts/devops/gha-secrets-verify.sh" ${REPO:+--repo "$REPO"} --required "$required"
    exit 2
  fi
  args=("$ROOT/scripts/devops/gha-secrets-set.sh" ${REPO:+--repo "$REPO"} --required "$required")
  if [ "$NON_INTERACTIVE" = "1" ]; then
    args+=("--non-interactive")
  fi
  "${args[@]}"
fi

REPO_ARG=()
if [ -n "${REPO:-}" ]; then REPO_ARG=(--repo "$REPO"); fi

dispatch_args=(
  "$ROOT/scripts/devops/gha-workflow-dispatch.sh"
  "${REPO_ARG[@]}"
  --workflow "cycle-005-supabase-provision-apply-verify.yml"
  --supabase-project-name "$SUPABASE_PROJECT_NAME"
  --reuse-existing "$REUSE_EXISTING"
  --sql-bundle "$SQL_BUNDLE"
)
if [ -n "${REF:-}" ]; then
  dispatch_args+=(--ref "$REF")
fi

RUN_ID="$("${dispatch_args[@]}")"
echo "Run id: $RUN_ID" >&2

if [ "$NO_WATCH" != "1" ]; then
  echo "Watching run (exit status reflects conclusion): gh run watch \"$RUN_ID\" -R \"${REPO:-<inferred>}\" --exit-status" >&2
  watch_rc=0
  # Always attempt artifact download/evidence capture even on failed runs.
  if [ -n "${REPO:-}" ]; then
    gh run watch -R "$REPO" "$RUN_ID" --exit-status || watch_rc="$?"
  else
    gh run watch "$RUN_ID" --exit-status || watch_rc="$?"
  fi
fi

"$ROOT/scripts/devops/gha-run-fetch-artifacts.sh" ${REPO:+--repo "$REPO"} --run-id "$RUN_ID"

echo "Evidence captured. See docs/devops/evidence/ for extracted artifacts (supabase-verify-run-$RUN_ID.json)." >&2

# If we watched the run and it failed, preserve a non-zero exit code for operators/CI.
if [ "${watch_rc:-0}" -ne 0 ]; then
  echo "WARNING: GitHub Actions run concluded non-success (watch exit code: $watch_rc)." >&2
  exit "$watch_rc"
fi
