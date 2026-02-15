#!/usr/bin/env bash
set -euo pipefail

# One-shot operator script:
# 1) verify/set required repo secrets for provisioning
# 2) dispatch/watch/download artifacts for cycle-005-supabase-provision-apply-verify

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-018-supabase-provision-apply-verify-one-shot.sh [flags]

Flags:
  --repo OWNER/REPO            (default: inferred via gh)
  --set-missing                If set, attempt to set missing secrets (values from env or prompts)
  --non-interactive            Fail if secret values are not provided via env (no prompts)
  --ref REF                    Optional ref for workflow dispatch
  --supabase-project-name NAME Optional override
  --reuse-existing true|false  (default: true)
  --sql-bundle PATH            Optional override

Examples:
  # Interactive prompts for missing secrets, then run the workflow
  scripts/devops/run-cycle-018-supabase-provision-apply-verify-one-shot.sh --repo OWNER/REPO --set-missing

  # Non-interactive (CI-friendly) using env vars
  SUPABASE_ACCESS_TOKEN=... SUPABASE_ORG_SLUG=... SUPABASE_DB_PASSWORD=... \
    scripts/devops/run-cycle-018-supabase-provision-apply-verify-one-shot.sh --repo OWNER/REPO --set-missing --non-interactive
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

REPO=""
SET_MISSING="0"
NON_INTERACTIVE="0"
REF=""
PROJECT_NAME=""
REUSE_EXISTING="true"
SQL_BUNDLE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --set-missing) SET_MISSING="1"; shift 1 ;;
    --non-interactive) NON_INTERACTIVE="1"; shift 1 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --supabase-project-name) PROJECT_NAME="${2:-}"; shift 2 ;;
    --reuse-existing) REUSE_EXISTING="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

secrets_args=()
if [ -n "${REPO:-}" ]; then
  secrets_args+=(--repo "$REPO")
fi
if [ "$SET_MISSING" = "1" ]; then
  secrets_args+=(--set-missing)
else
  secrets_args+=(--check-only)
fi
if [ "$NON_INTERACTIVE" = "1" ]; then
  secrets_args+=(--non-interactive)
fi

"$root/scripts/devops/gh-ensure-supabase-provision-secrets.sh" "${secrets_args[@]}"

run_args=()
if [ -n "${REPO:-}" ]; then
  run_args+=(--repo "$REPO")
fi
if [ -n "${REF:-}" ]; then
  run_args+=(--ref "$REF")
fi
if [ -n "${PROJECT_NAME:-}" ]; then
  run_args+=(--supabase-project-name "$PROJECT_NAME")
fi
run_args+=(--reuse-existing "$REUSE_EXISTING")
if [ -n "${SQL_BUNDLE:-}" ]; then
  run_args+=(--sql-bundle "$SQL_BUNDLE")
fi

"$root/scripts/devops/gh-dispatch-cycle-005-supabase-provision-apply-verify.sh" "${run_args[@]}"
