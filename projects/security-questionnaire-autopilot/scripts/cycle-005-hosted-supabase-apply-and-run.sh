#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:3000}"
RUN_ID="${2:-pilot-001-customer-originated-$(date +%Y%m%d-%H%M%S)}"
BASE_URL="${BASE_URL%/}"

# Repo root (this script lives in projects/security-questionnaire-autopilot/scripts).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROJECT="$ROOT/projects/security-questionnaire-autopilot"
QA_DIR="$ROOT/docs/qa"
DEVOPS_DIR="$ROOT/docs/devops"
SALES_DIR="$ROOT/docs/sales"

BUNDLE_SQL="$PROJECT/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
MIGRATION_SQL="$PROJECT/supabase/migrations/20260213_cycle003_hosted_workflow.sql"
SEED_SQL="$PROJECT/supabase/seed/pilot-001-floor-pricing.sql"

QUESTIONNAIRE_FILE="$SALES_DIR/cycle-004-pilot-001-customer-questionnaire.csv"
SRC1_FILE="$SALES_DIR/cycle-004-pilot-001-source-security-program.md"
SRC2_FILE="$SALES_DIR/cycle-004-pilot-001-source-incident-response.md"
SRC3_FILE="$SALES_DIR/cycle-004-pilot-001-source-infrastructure-controls.md"

mkdir -p "$QA_DIR" "$DEVOPS_DIR"

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

safe_id() {
  # Make RUN_ID safe for filenames.
  printf '%s' "$1" | tr -cs 'A-Za-z0-9_.-' '_'
}

require_bin "curl"
require_bin "jq"
require_bin "node"

# Node 18+ required (global fetch). Node 20+ recommended (project engines).
NODE_MAJOR="$(node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null || echo 0)"
if [ "${NODE_MAJOR:-0}" -lt 18 ]; then
  echo "Node >=18 is required. Detected: $(node -v 2>/dev/null || echo 'unknown')" >&2
  exit 2
fi
if [ "${NODE_MAJOR:-0}" -lt 20 ]; then
  echo "Warning: Node 20+ is recommended (project engines). Detected: $(node -v)" >&2
fi

# Ensure node scripts run from the project directory even when SQL apply is skipped.
cd "$PROJECT"

SAFE_RUN_ID="$(safe_id "$RUN_ID")"
ENV_HEALTH_OUT="$QA_DIR/cycle-005-env-health-${SAFE_RUN_ID}.json"
SUPABASE_HEALTH_OUT="$QA_DIR/cycle-005-supabase-health-${SAFE_RUN_ID}.json"
VALIDATE_OUT="$QA_DIR/cycle-005-hosted-validate-${SAFE_RUN_ID}.json"
INGEST_OUT="$QA_DIR/cycle-005-hosted-ingest-${SAFE_RUN_ID}.json"
DRAFT_OUT="$QA_DIR/cycle-005-hosted-draft-${SAFE_RUN_ID}.json"
APPROVE_OUT="$QA_DIR/cycle-005-hosted-approve-${SAFE_RUN_ID}.json"
EXPORT_OUT="$QA_DIR/cycle-005-hosted-export-${SAFE_RUN_ID}.json"
INTAKE_DIR="/tmp/cycle-005-hosted-intake-${SAFE_RUN_ID}"

echo "[0/8] hosted env preflight (no secrets)"
ENV_HEALTH_CODE="$(curl -sS -o "$ENV_HEALTH_OUT" -w "%{http_code}" "$BASE_URL/api/workflow/env-health" || echo "000")"
if [ "$ENV_HEALTH_CODE" != "200" ]; then
  echo "env-health failed (HTTP $ENV_HEALTH_CODE). See: $ENV_HEALTH_OUT" >&2
  exit 2
fi
if ! jq -e '.ok == true' "$ENV_HEALTH_OUT" >/dev/null 2>&1; then
  echo "env-health returned 200 but not ok=true. See: $ENV_HEALTH_OUT" >&2
  exit 2
fi
if ! jq -e '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$ENV_HEALTH_OUT" >/dev/null 2>&1; then
  echo "Hosted runtime is missing required Supabase env vars. See: $ENV_HEALTH_OUT" >&2
  echo "Expected: NEXT_PUBLIC_SUPABASE_URL=true and SUPABASE_SERVICE_ROLE_KEY=true" >&2
  "$PROJECT/scripts/print-hosted-supabase-env-setup-help.sh" "$BASE_URL" || true
  exit 2
fi

SKIP_APPLY="${SKIP_SUPABASE_SQL_APPLY:-}"
if [ -n "$SKIP_APPLY" ] && [ "$SKIP_APPLY" != "0" ]; then
  echo "[1/8] skipping migration + seed apply (SKIP_SUPABASE_SQL_APPLY is set)"
else
  if [ -z "${SUPABASE_DB_URL:-}" ]; then
    echo "Missing env var: SUPABASE_DB_URL" >&2
    echo "" >&2
    echo "To proceed, choose ONE:" >&2
    echo "  1) Apply the bundle via Supabase Dashboard SQL Editor, then rerun with:" >&2
    echo "     export SKIP_SUPABASE_SQL_APPLY=1" >&2
    echo "  2) Provide a direct Postgres connection string and rerun with:" >&2
    echo "     export SUPABASE_DB_URL='postgresql://postgres:...@db.<project-ref>.supabase.co:5432/postgres'" >&2
    exit 2
  fi
	echo "[1/8] apply migration + seed to Supabase (via node + pg)"
	# Prefer applying the bundle so the DB apply path matches the Dashboard SQL Editor path.
	if [ -f "$BUNDLE_SQL" ]; then
	  node scripts/verify-dashboard-sql-bundle.mjs --bundle "$BUNDLE_SQL" >/dev/null
	  node scripts/apply-supabase-sql.mjs "$BUNDLE_SQL"
	else
	  node scripts/apply-supabase-sql.mjs "$MIGRATION_SQL" "$SEED_SQL"
	fi
fi

echo "[2/8] hosted supabase persistence health check (env + schema + seed)"
SUPABASE_HEALTH_CODE="$(curl -sS -o "$SUPABASE_HEALTH_OUT" -w "%{http_code}" "$BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" || echo "000")"
if [ "$SUPABASE_HEALTH_CODE" != "200" ]; then
  echo "Supabase health check failed (HTTP $SUPABASE_HEALTH_CODE). See: $SUPABASE_HEALTH_OUT" >&2
  exit 2
fi
if ! jq -e '.ok == true' "$SUPABASE_HEALTH_OUT" >/dev/null 2>&1; then
  echo "Supabase health check returned 200 but not ok=true. See: $SUPABASE_HEALTH_OUT" >&2
  exit 2
fi

if [ ! -f "$QUESTIONNAIRE_FILE" ] || [ ! -f "$SRC1_FILE" ] || [ ! -f "$SRC2_FILE" ] || [ ! -f "$SRC3_FILE" ]; then
  echo "Missing intake files in docs/sales/. Expected:" >&2
  echo "  $QUESTIONNAIRE_FILE" >&2
  echo "  $SRC1_FILE" >&2
  echo "  $SRC2_FILE" >&2
  echo "  $SRC3_FILE" >&2
  exit 2
fi

echo "[3/8] run hosted workflow intake (customer-originated payload)"
./scripts/hosted-workflow-customer-intake.sh "$BASE_URL" "$RUN_ID" "$INTAKE_DIR"

# Copy deterministic artifacts into docs/qa for sales/QA linking.
cp -f "$INTAKE_DIR/responses/01-validate-pilot-deal.json" "$VALIDATE_OUT"
cp -f "$INTAKE_DIR/responses/02-ingest.json" "$INGEST_OUT"
cp -f "$INTAKE_DIR/responses/03-draft.json" "$DRAFT_OUT"
cp -f "$INTAKE_DIR/responses/04-approve.json" "$APPROVE_OUT"
cp -f "$INTAKE_DIR/responses/05-export.json" "$EXPORT_OUT"

echo "[4/8] fetch DB persistence evidence (workflow_runs + workflow_events)"
EVIDENCE_OUT="$DEVOPS_DIR/cycle-005-supabase-persistence-${SAFE_RUN_ID}.json"

# Prefer fetching evidence from the hosted runtime (no local Supabase secrets needed).
HOSTED_DB_EVIDENCE_RAW="$INTAKE_DIR/responses/06-db-evidence.json"
HOSTED_DB_EVIDENCE_STATUS="$(cat "$INTAKE_DIR/responses/06-db-evidence.status" 2>/dev/null || echo "000")"
if [ "$HOSTED_DB_EVIDENCE_STATUS" = "200" ] && jq -e '.ok == true' "$HOSTED_DB_EVIDENCE_RAW" >/dev/null 2>&1; then
	# Normalize hosted evidence schema to match scripts/fetch-supabase-workflow-evidence.mjs output.
	jq '{
	  runId: (.runId // .run_id),
	  fetchedAt: (.fetchedAt // (now | todateiso8601)),
	  expectedSchema: (.expectedSchema // null),
	  workflow_runs: (.workflow_runs // .workflowRun),
	  workflow_events: (.workflow_events // .workflowEvents // [])
	}' "$HOSTED_DB_EVIDENCE_RAW" > "$EVIDENCE_OUT"
else
  # Fallback: direct PostgREST evidence fetch from local machine (requires local env).
  require_env "NEXT_PUBLIC_SUPABASE_URL"
  require_env "SUPABASE_SERVICE_ROLE_KEY"
  node scripts/fetch-supabase-workflow-evidence.mjs --run-id "$RUN_ID" --out "$EVIDENCE_OUT"
fi

echo "[5/8] validate DB persistence evidence (QA acceptance)"
REQUIRE_SCHEMA_MATCH=1 node scripts/validate-supabase-workflow-evidence.mjs --evidence "$EVIDENCE_OUT"

echo "[6/8] attach evidence path into sales execution ledger"
SALES_DOC="$ROOT/docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md"
node scripts/append-supabase-evidence-to-sales-doc.mjs \
  --run-id "$RUN_ID" \
  --evidence "$EVIDENCE_OUT" \
  --doc "$SALES_DOC" \
  --base-url "$BASE_URL" \
  --env-health "$ENV_HEALTH_OUT" \
  --supabase-health "$SUPABASE_HEALTH_OUT"

echo "[6b/8] write deterministic run metadata (for audit trails)"
META_OUT="$DEVOPS_DIR/cycle-005-hosted-supabase-run-metadata-${SAFE_RUN_ID}.txt"
cat > "$META_OUT" <<EOF
run_id=$RUN_ID
base_url=$BASE_URL
timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
qa_env_health=$ENV_HEALTH_OUT
qa_supabase_health=$SUPABASE_HEALTH_OUT
evidence=$EVIDENCE_OUT
intake_dir=$INTAKE_DIR
EOF

echo "[7/8] summary"
echo "run_id=$RUN_ID"
echo "base_url=$BASE_URL"
echo "qa_env_health=$ENV_HEALTH_OUT"
echo "qa_supabase_health=$SUPABASE_HEALTH_OUT"
echo "qa_validate=$VALIDATE_OUT"
echo "qa_ingest=$INGEST_OUT"
echo "qa_draft=$DRAFT_OUT"
echo "qa_approve=$APPROVE_OUT"
echo "qa_export=$EXPORT_OUT"
echo "intake_dir=$INTAKE_DIR"
echo "evidence=$EVIDENCE_OUT"
echo "metadata=$META_OUT"

echo "[8/8] done"
