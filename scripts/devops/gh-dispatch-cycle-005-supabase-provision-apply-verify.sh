#!/usr/bin/env bash
set -euo pipefail

# Operator wrapper:
# - dispatch `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`
# - wait for completion
# - download artifact `cycle-005-supabase-provision-apply-verify`
# - copy key evidence files into docs/qa-bach/
#
# Outputs (default):
#   docs/qa-bach/cycle-018-supabase-provision-apply-verify-run-<ts>/
#     - dispatch.json
#     - dispatch.log
#     - watch.log
#     - artifact/...
#     - supabase-connection-nonsecret.txt (if present)
#     - supabase-provision-summary.json   (if present)
#     - supabase-provision.kv             (if present)
#     - supabase-verify.json              (if present)

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/gh-dispatch-cycle-005-supabase-provision-apply-verify.sh [flags]

Flags:
  --repo OWNER/REPO                 (default: inferred via gh)
  --ref REF                         Optional git ref (branch/tag/SHA) for workflow dispatch
  --supabase-project-name NAME      (default: workflow default)
  --reuse-existing true|false       (default: true)
  --sql-bundle PATH                 Workspace-relative SQL bundle path (default: workflow default)
  --out-dir DIR                     Evidence output dir
  --no-watch                        Do not wait for completion (still records run id/url)

Example:
  scripts/devops/gh-dispatch-cycle-005-supabase-provision-apply-verify.sh --repo OWNER/REPO
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

REPO=""
REF=""
PROJECT_NAME=""
REUSE_EXISTING="true"
SQL_BUNDLE=""
OUT_DIR=""
WATCH="1"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --supabase-project-name) PROJECT_NAME="${2:-}"; shift 2 ;;
    --reuse-existing) REUSE_EXISTING="${2:-}"; shift 2 ;;
    --sql-bundle) SQL_BUNDLE="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --no-watch) WATCH="0"; shift 1 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

case "$REUSE_EXISTING" in
  true|false) ;;
  *) echo "Invalid --reuse-existing value: $REUSE_EXISTING (expected true|false)" >&2; exit 2 ;;
esac

gh auth status -h github.com >/dev/null

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

perm="$(gh repo view "$REPO" --json viewerPermission -q .viewerPermission 2>/dev/null || echo "")"
case "$perm" in
  ADMIN|MAINTAIN|WRITE) ;;
  *)
    echo "Insufficient GitHub repo permission to dispatch workflows." >&2
    echo "repo=$REPO viewerPermission=${perm:-unknown}" >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ts="$(date -u +"%Y%m%dT%H%M%SZ")"
if [ -z "${OUT_DIR:-}" ]; then
  OUT_DIR="$ROOT/docs/qa-bach/cycle-018-supabase-provision-apply-verify-run-${ts}"
fi
mkdir -p "$OUT_DIR"

wf="cycle-005-supabase-provision-apply-verify.yml"
artifact_name="cycle-005-supabase-provision-apply-verify"

start_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

ref_args=()
if [ -n "${REF:-}" ]; then
  ref_args+=(--ref "$REF")
fi

inputs=()
if [ -n "${PROJECT_NAME:-}" ]; then
  inputs+=(-f "supabase_project_name=$PROJECT_NAME")
fi
inputs+=(-f "reuse_existing=$REUSE_EXISTING")
if [ -n "${SQL_BUNDLE:-}" ]; then
  inputs+=(-f "sql_bundle=$SQL_BUNDLE")
fi

dispatch_cmd=(gh workflow run "$wf" -R "$REPO" "${ref_args[@]}" "${inputs[@]}")
printf '%s\n' "Dispatching: ${dispatch_cmd[*]}" >"$OUT_DIR/dispatch.log"
if ! "${dispatch_cmd[@]}" >>"$OUT_DIR/dispatch.log" 2>&1; then
  cat "$OUT_DIR/dispatch.log" >&2 || true
  exit 2
fi

query="map(select(.createdAt >= \"$start_ts\")) | .[0].databaseId"
run_dbid="$(gh run list -R "$REPO" --workflow "$wf" -L 20 --json databaseId,createdAt -q "$query" 2>/dev/null || true)"
if [ -z "${run_dbid:-}" ] || [ "${run_dbid:-}" = "null" ]; then
  run_dbid="$(gh run list -R "$REPO" --workflow "$wf" -L 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
fi
if [ -z "${run_dbid:-}" ] || [ "${run_dbid:-}" = "null" ]; then
  echo "Could not locate a run id after dispatch. Use:" >&2
  echo "  gh run list -R \"$REPO\" --workflow \"$wf\" -L 10" >&2
  exit 2
fi

run_url="$(gh run view -R "$REPO" "$run_dbid" --json htmlUrl -q '.htmlUrl' 2>/dev/null || true)"
if [ -z "${run_url:-}" ] || [ "${run_url:-}" = "null" ]; then
  run_url="$(gh run view -R "$REPO" "$run_dbid" --json url -q '.url' 2>/dev/null || true)"
fi

jq -n \
  --arg repo "$REPO" \
  --arg workflow "$wf" \
  --arg run_database_id "$run_dbid" \
  --arg run_url "${run_url:-}" \
  --arg dispatched_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg out_dir "$OUT_DIR" \
  --arg artifact_name "$artifact_name" \
  '{
    repo: $repo,
    workflow: $workflow,
    run_database_id: $run_database_id,
    run_url: ($run_url | select(length > 0)),
    dispatched_at_utc: $dispatched_at_utc,
    artifact_name: $artifact_name,
    out_dir: $out_dir
  }' >"$OUT_DIR/dispatch.json"

echo "GHA run databaseId: $run_dbid"
if [ -n "${run_url:-}" ] && [ "${run_url:-}" != "null" ]; then
  echo "GHA run url: $run_url"
fi

if [ "$WATCH" != "1" ]; then
  exit 0
fi

echo "Watching run..."
gh run watch -R "$REPO" "$run_dbid" --exit-status 2>&1 | tee "$OUT_DIR/watch.log" >/dev/null || true

mkdir -p "$OUT_DIR/artifact"
gh run download -R "$REPO" "$run_dbid" -n "$artifact_name" -D "$OUT_DIR/artifact" >>"$OUT_DIR/watch.log" 2>&1 || true

copy_first() {
  local filename="$1"
  local dest="$2"
  local p
  p="$(find "$OUT_DIR/artifact" -type f -name "$filename" 2>/dev/null | head -n 1 || true)"
  if [ -n "${p:-}" ]; then
    cp -f "$p" "$dest"
    return 0
  fi
  return 1
}

copy_first "supabase-connection-nonsecret.txt" "$OUT_DIR/supabase-connection-nonsecret.txt" || true
copy_first "supabase-provision-summary.json" "$OUT_DIR/supabase-provision-summary.json" || true
copy_first "supabase-provision.kv" "$OUT_DIR/supabase-provision.kv" || true

if copy_first "supabase-verify.json" "$OUT_DIR/supabase-verify.json"; then
  if jq -e '.ok == true' "$OUT_DIR/supabase-verify.json" >/dev/null 2>&1; then
    echo "supabase-verify.json: ok=true"
  else
    echo "supabase-verify.json: ok=false (see $OUT_DIR/supabase-verify.json)" >&2
  fi
else
  echo "Artifact did not include supabase-verify.json (see $OUT_DIR/artifact)." >&2
fi

