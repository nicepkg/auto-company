#!/usr/bin/env bash
set -euo pipefail

# Download workflow run artifacts and extract the Supabase verification JSON into an evidence directory.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/gha-run-fetch-artifacts.sh [flags]

Flags:
  --repo OWNER/REPO         (default: inferred via gh or git remote)
  --run-id ID               required
  --artifact-name NAME      (default: cycle-005-supabase-provision-apply-verify)
  --evidence-dir DIR        (default: docs/devops/evidence)
  --dest DIR                (default: <evidence-dir>/artifacts/run-<id>)
  --out PATH                (default: <evidence-dir>/artifact-fetch-<ts>-run-<id>.json)

Outputs:
  - Copies `projects/security-questionnaire-autopilot/runs/supabase-verify.json` to:
      <evidence-dir>/supabase-verify-run-<id>.json
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

REPO=""
RUN_ID=""
ARTIFACT_NAME="cycle-005-supabase-provision-apply-verify"
EVIDENCE_DIR=""
DEST=""
OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --artifact-name) ARTIFACT_NAME="${2:-}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    --dest) DEST="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_bin gh
require_bin jq

if [ -n "${EVIDENCE_DIR:-}" ]; then
  EVID_DIR="$EVIDENCE_DIR"
fi
mkdir -p "$EVID_DIR"

if [ -z "${RUN_ID:-}" ]; then
  echo "Missing --run-id" >&2
  usage
  exit 2
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

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
if [ -z "${DEST:-}" ]; then
  DEST="$EVID_DIR/artifacts/run-$RUN_ID"
fi
if [ -z "${OUT:-}" ]; then
  OUT="$EVID_DIR/artifact-fetch-$ts-run-$RUN_ID.json"
fi

mkdir -p "$DEST"

if ! gh run download -R "$REPO" "$RUN_ID" -n "$ARTIFACT_NAME" -D "$DEST" >/dev/null 2>&1; then
  jq -n \
    --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg repo "$REPO" \
    --arg run_id "$RUN_ID" \
    --arg artifact "$ARTIFACT_NAME" \
    --arg dest "$DEST" \
    '{checked_at_utc:$checked_at_utc, repo:$repo, run_id:($run_id|tonumber), artifact:$artifact, dest:$dest, error:"Failed to download artifact (missing artifact name, permissions, or run id)."}' \
    >"$OUT"
  echo "ERROR: artifact download failed. Evidence: $OUT" >&2
  echo "Debug:" >&2
  echo "  gh run view -R \"$REPO\" \"$RUN_ID\"" >&2
  echo "  gh run download -R \"$REPO\" \"$RUN_ID\" -D \"$DEST\"" >&2
  exit 2
fi

verify_src="$DEST/projects/security-questionnaire-autopilot/runs/supabase-verify.json"
verify_dst="$EVID_DIR/supabase-verify-run-$RUN_ID.json"
conn_src="$DEST/projects/security-questionnaire-autopilot/runs/supabase-connection-nonsecret.txt"
conn_dst="$EVID_DIR/supabase-connection-nonsecret-run-$RUN_ID.txt"
prov_src="$DEST/projects/security-questionnaire-autopilot/runs/supabase-provision-summary.json"
prov_dst="$EVID_DIR/supabase-provision-summary-run-$RUN_ID.json"

copied=()
verify_present="false"
conn_present="false"
prov_present="false"
if [ -f "$verify_src" ]; then
  cp "$verify_src" "$verify_dst"
  copied+=("$verify_dst")
  verify_present="true"
fi
if [ -f "$conn_src" ]; then
  cp "$conn_src" "$conn_dst"
  copied+=("$conn_dst")
  conn_present="true"
fi
if [ -f "$prov_src" ]; then
  cp "$prov_src" "$prov_dst"
  copied+=("$prov_dst")
  prov_present="true"
fi

files_json="$(find "$DEST" -type f -maxdepth 6 -print 2>/dev/null | sed "s#^$DEST/##" | jq -R . | jq -s .)"

jq -n \
  --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg repo "$REPO" \
  --arg run_id "$RUN_ID" \
  --arg artifact "$ARTIFACT_NAME" \
  --arg dest "$DEST" \
  --arg verify_src "$verify_src" \
  --arg verify_dst "$verify_dst" \
  --arg verify_present "$verify_present" \
  --arg conn_src "$conn_src" \
  --arg conn_dst "$conn_dst" \
  --arg conn_present "$conn_present" \
  --arg prov_src "$prov_src" \
  --arg prov_dst "$prov_dst" \
  --arg prov_present "$prov_present" \
  --argjson files "$files_json" \
  --argjson copied "$(printf '%s\n' "${copied[@]:-}" | jq -R . | jq -s .)" \
  '{checked_at_utc:$checked_at_utc, repo:$repo, run_id:($run_id|tonumber), artifact:$artifact, dest:$dest, files:$files, extracted:{supabase_verify:{src:$verify_src, dst:$verify_dst, present:($verify_present=="true")}, connection_hints:{src:$conn_src, dst:$conn_dst, present:($conn_present=="true")}, provision_summary:{src:$prov_src, dst:$prov_dst, present:($prov_present=="true")}}, copied:$copied}' \
  >"$OUT"

if [ ! -f "$verify_dst" ]; then
  echo "WARNING: supabase-verify.json not found in artifact. Evidence: $OUT" >&2
  exit 2
fi

echo "Extracted: $verify_dst" >&2
echo "Evidence: $OUT" >&2
