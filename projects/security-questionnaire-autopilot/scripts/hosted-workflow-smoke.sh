#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:3000}"
RUN_ID="${2:-pilot-hosted-smoke-$(date +%Y%m%d-%H%M%S)}"

post() {
  local endpoint="$1"
  local payload="$2"
  curl -sS -X POST "$BASE_URL$endpoint" \
    -H 'content-type: application/json' \
    -d "$payload"
}

echo "[1/5] validate floor pricing"
post "/api/workflow/validate-pilot-deal" "{
  \"runId\": \"$RUN_ID\",
  \"onboardingFee\": 2000,
  \"monthlyFee\": 1800,
  \"includedQuestionnaires\": 12,
  \"overageFee\": 150,
  \"expectedQuestionnaires\": 14,
  \"estimatedCogsPerQuestionnaire\": 35
}" | jq .

echo "[2/5] ingest"
post "/api/workflow/ingest" "{\"runId\":\"$RUN_ID\"}" | jq .

echo "[3/5] draft"
post "/api/workflow/draft" "{\"runId\":\"$RUN_ID\"}" | jq .

echo "[4/5] approve"
post "/api/workflow/approve" "{
  \"runId\": \"$RUN_ID\",
  \"reviewer\": \"Pilot One Reviewer\",
  \"decisions\": [
    {\"questionId\":\"Q-001\",\"decision\":\"approve\",\"notes\":\"ok\"},
    {\"questionId\":\"Q-002\",\"decision\":\"approve\",\"notes\":\"ok\"},
    {\"questionId\":\"Q-003\",\"decision\":\"approve\",\"notes\":\"ok\"},
    {\"questionId\":\"Q-004\",\"decision\":\"approve\",\"notes\":\"ok\"},
    {\"questionId\":\"Q-005\",\"decision\":\"approve\",\"notes\":\"ok\"},
    {\"questionId\":\"Q-006\",\"decision\":\"approve\",\"notes\":\"ok\"}
  ]
}" | jq .

echo "[5/5] export"
post "/api/workflow/export" "{\"runId\":\"$RUN_ID\"}" | jq .

echo "Hosted workflow smoke complete for run: $RUN_ID"
