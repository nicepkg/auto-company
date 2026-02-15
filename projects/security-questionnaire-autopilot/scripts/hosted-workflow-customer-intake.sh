#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:3000}"
RUN_ID="${2:-pilot-001-customer-originated-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="${3:-/tmp/hosted-intake-${RUN_ID}}"
BASE_URL="${BASE_URL%/}"

# Repo root (this script lives in projects/security-questionnaire-autopilot/scripts).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SALES_DIR="$ROOT/docs/sales"

QUESTIONNAIRE_CSV_FILE="${QUESTIONNAIRE_CSV_FILE:-$SALES_DIR/cycle-004-pilot-001-customer-questionnaire.csv}"
SOURCE_1_FILE="${SOURCE_1_FILE:-$SALES_DIR/cycle-004-pilot-001-source-security-program.md}"
SOURCE_2_FILE="${SOURCE_2_FILE:-$SALES_DIR/cycle-004-pilot-001-source-incident-response.md}"
SOURCE_3_FILE="${SOURCE_3_FILE:-$SALES_DIR/cycle-004-pilot-001-source-infrastructure-controls.md}"

mkdir -p "$OUT_DIR/requests" "$OUT_DIR/responses"

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "jq"

post_json_file() {
  local name="$1"
  local endpoint="$2"
  local req_file="$3"
  local allow_failure="${4:-0}"

  local resp_file="$OUT_DIR/responses/${name}.json"
  local status_file="$OUT_DIR/responses/${name}.status"

  # `db-evidence` is intentionally best-effort so the workflow can still be
  # executed in environments where Supabase env vars are not yet configured.
  local status="000"
  local curl_rc=0
  set +e
  status="$(curl -sS -o "$resp_file" -w "%{http_code}" \
    -X POST "$BASE_URL$endpoint" \
    -H 'content-type: application/json' \
    --data-binary "@$req_file")"
  curl_rc=$?
  set -e

  if [ "$curl_rc" -ne 0 ] && [ "$allow_failure" = "0" ]; then
    echo "Request failed: POST $endpoint (curl exit $curl_rc)" >&2
    exit "$curl_rc"
  fi

  printf "%s\n" "$status" > "$status_file"

  # Best-effort pretty print for humans; raw JSON is kept too.
  jq . "$resp_file" > "$resp_file.pretty" 2>/dev/null || true
}

echo "Preparing request payloads in $OUT_DIR"

jq -n \
  --arg runId "$RUN_ID" \
  --argjson onboardingFee 2000 \
  --argjson monthlyFee 1800 \
  --argjson includedQuestionnaires 12 \
  --argjson overageFee 150 \
  --argjson expectedQuestionnaires 14 \
  --argjson estimatedCogsPerQuestionnaire 35 \
  '{
    runId: $runId,
    onboardingFee: $onboardingFee,
    monthlyFee: $monthlyFee,
    includedQuestionnaires: $includedQuestionnaires,
    overageFee: $overageFee,
    expectedQuestionnaires: $expectedQuestionnaires,
    estimatedCogsPerQuestionnaire: $estimatedCogsPerQuestionnaire
  }' > "$OUT_DIR/requests/01-validate-pilot-deal.json"

jq -n \
  --arg runId "$RUN_ID" \
  --rawfile questionnaireCsv "$QUESTIONNAIRE_CSV_FILE" \
  --rawfile source1 "$SOURCE_1_FILE" \
  --rawfile source2 "$SOURCE_2_FILE" \
  --rawfile source3 "$SOURCE_3_FILE" \
  '{
    runId: $runId,
    questionnaireCsv: $questionnaireCsv,
    sources: [
      { fileName: "customer-source-security-program.md", content: $source1 },
      { fileName: "customer-source-incident-response.md", content: $source2 },
      { fileName: "customer-source-infrastructure-controls.md", content: $source3 }
    ]
  }' > "$OUT_DIR/requests/02-ingest.json"

jq -n --arg runId "$RUN_ID" '{ runId: $runId }' > "$OUT_DIR/requests/03-draft.json"

# Approve based on question IDs in the questionnaire file (Cycle-004 uses Q-CUST-001..006).
jq -n \
  --arg runId "$RUN_ID" \
  '{
    runId: $runId,
    reviewer: "Pilot One Security Reviewer",
    decisions: [
      { questionId: "Q-CUST-001", decision: "approve", notes: "ok" },
      { questionId: "Q-CUST-002", decision: "approve", notes: "ok" },
      { questionId: "Q-CUST-003", decision: "approve", notes: "ok" },
      { questionId: "Q-CUST-004", decision: "approve", notes: "ok" },
      { questionId: "Q-CUST-005", decision: "approve", notes: "ok" },
      { questionId: "Q-CUST-006", decision: "approve", notes: "ok" }
    ]
  }' > "$OUT_DIR/requests/04-approve.json"

jq -n --arg runId "$RUN_ID" '{ runId: $runId }' > "$OUT_DIR/requests/05-export.json"
jq -n --arg runId "$RUN_ID" '{ runId: $runId }' > "$OUT_DIR/requests/06-db-evidence.json"

echo "[1/6] validate-pilot-deal"
post_json_file "01-validate-pilot-deal" "/api/workflow/validate-pilot-deal" "$OUT_DIR/requests/01-validate-pilot-deal.json"

echo "[2/6] ingest"
post_json_file "02-ingest" "/api/workflow/ingest" "$OUT_DIR/requests/02-ingest.json"

echo "[3/6] draft"
post_json_file "03-draft" "/api/workflow/draft" "$OUT_DIR/requests/03-draft.json"

echo "[4/6] approve"
post_json_file "04-approve" "/api/workflow/approve" "$OUT_DIR/requests/04-approve.json"

echo "[5/6] export"
post_json_file "05-export" "/api/workflow/export" "$OUT_DIR/requests/05-export.json"

echo "[6/6] db-evidence (requires Supabase env vars set on server)"
post_json_file "06-db-evidence" "/api/workflow/db-evidence" "$OUT_DIR/requests/06-db-evidence.json" 1

echo "Hosted customer intake complete."
echo "run_id=$RUN_ID"
echo "out_dir=$OUT_DIR"
