#!/usr/bin/env bash
set -euo pipefail

# CTO operator wrapper (Cycle 18 objective):
# With only a GitHub token (plus the Supabase secret values you intend to store),
# an operator can:
# 1) verify required repo secrets exist
# 2) set missing secrets (via gh)
# 3) dispatch the Supabase provision+apply+verify workflow
# 4) wait for completion
# 5) download artifacts incl. supabase-verify.json into docs/cto/

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-018-supabase-ci-cto.sh [flags]

Flags:
  --repo OWNER/REPO             (default: inferred via gh or git remote)
  --ref REF                     optional ref for workflow dispatch
  --set-missing                 if required secrets are missing, prompt and set them via gh
  --non-interactive             used with --set-missing; requires env vars to be set (no prompting)
  --supabase-project-name NAME  (default: security-questionnaire-autopilot-cycle-005)
  --reuse-existing true|false   (default: true)
  --sql-bundle PATH             (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --no-watch                    dispatch only; skip waiting for completion (still resolves run id)
  --run-id ID                   skip secrets+dispatch; only download artifacts for an existing run id
  --evidence-dir DIR            (default: docs/cto/cycle-018-supabase-ci)

Env (used when --set-missing --non-interactive):
  SUPABASE_ACCESS_TOKEN
  SUPABASE_ORG_SLUG
  SUPABASE_DB_PASSWORD

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
require_bin jq

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO=""
REF=""
SET_MISSING="0"
NON_INTERACTIVE="0"
SUPABASE_PROJECT_NAME="security-questionnaire-autopilot-cycle-005"
REUSE_EXISTING="true"
SQL_BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
NO_WATCH="0"
RUN_ID=""
EVID_DIR="$ROOT/docs/cto/cycle-018-supabase-ci"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --set-missing) SET_MISSING="1"; shift 1 ;;
    --non-interactive) NON_INTERACTIVE="1"; shift 1 ;;
    --supabase-project-name) SUPABASE_PROJECT_NAME="${2:-}"; shift 2 ;;
    --reuse-existing) REUSE_EXISTING="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --no-watch) NO_WATCH="1"; shift 1 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --evidence-dir) EVID_DIR="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$EVID_DIR"
ts="$(date -u +"%Y%m%dT%H%M%SZ")"

REPO_ARG=()
if [ -n "${REPO:-}" ]; then
  REPO_ARG=(--repo "$REPO")
fi

if [ -n "${RUN_ID:-}" ]; then
  "$ROOT/scripts/devops/gha-run-fetch-artifacts.sh" "${REPO_ARG[@]}" \
    --run-id "$RUN_ID" \
    --evidence-dir "$EVID_DIR" \
    --dest "$EVID_DIR/runs/$RUN_ID-$ts/artifacts" \
    --out "$EVID_DIR/runs/$RUN_ID-$ts/artifact-fetch.json"
  exit 0
fi

# 1) Verify / set required secrets (names only).
secrets_args=("${REPO_ARG[@]}")
if [ "$SET_MISSING" = "1" ]; then
  secrets_args+=(--set-missing)
else
  secrets_args+=(--check-only)
fi
if [ "$NON_INTERACTIVE" = "1" ]; then
  secrets_args+=(--non-interactive)
fi
secrets_args+=(--out-json "$EVID_DIR/secrets-$ts.json" --out-log "$EVID_DIR/secrets-$ts.log")

"$ROOT/scripts/devops/gh-ensure-supabase-provision-secrets.sh" "${secrets_args[@]}"

# 2) Dispatch and resolve run id + evidence.
dispatch_args=(
  "$ROOT/scripts/devops/gha-workflow-dispatch.sh"
  "${REPO_ARG[@]}"
  --workflow "cycle-005-supabase-provision-apply-verify.yml"
  --supabase-project-name "$SUPABASE_PROJECT_NAME"
  --reuse-existing "$REUSE_EXISTING"
  --sql-bundle "$SQL_BUNDLE"
  --out "$EVID_DIR/dispatch-$ts.json"
)
if [ -n "${REF:-}" ]; then
  dispatch_args+=(--ref "$REF")
fi

RUN_ID="$("${dispatch_args[@]}")"
echo "Run id: $RUN_ID" >&2

if [ "$NO_WATCH" != "1" ]; then
  echo "Watching run..." >&2
  if [ -n "${REPO:-}" ]; then
    gh run watch -R "$REPO" "$RUN_ID" --exit-status 2>&1 | tee "$EVID_DIR/watch-$RUN_ID-$ts.log" >/dev/null
  else
    gh run watch "$RUN_ID" --exit-status 2>&1 | tee "$EVID_DIR/watch-$RUN_ID-$ts.log" >/dev/null
  fi
else
  echo "Not watching (per --no-watch)." >&2
fi

# 3) Download artifacts and extract supabase-verify.json into docs/cto/.
"$ROOT/scripts/devops/gha-run-fetch-artifacts.sh" "${REPO_ARG[@]}" \
  --run-id "$RUN_ID" \
  --evidence-dir "$EVID_DIR" \
  --dest "$EVID_DIR/runs/$RUN_ID-$ts/artifacts" \
  --out "$EVID_DIR/runs/$RUN_ID-$ts/artifact-fetch.json"

echo "OK. Evidence in: $EVID_DIR" >&2

