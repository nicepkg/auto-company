#!/usr/bin/env bash
set -euo pipefail

# Verify required GitHub Actions secrets exist (names only) and write a JSON evidence file.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/gha-secrets-verify.sh [flags]

Flags:
  --repo OWNER/REPO        (default: inferred via gh or git remote)
  --required "A B C"       (default: SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD)
  --out PATH               (default: docs/devops/evidence/actions-secrets-check-<ts>.json)

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

infer_repo_from_git() {
  local u owner repo
  u="$(git remote get-url origin 2>/dev/null || true)"
  if [ -z "${u:-}" ]; then
    return 1
  fi
  # Supports:
  # - git@github.com:OWNER/REPO.git
  # - https://github.com/OWNER/REPO.git
  u="${u%.git}"
  if [[ "$u" =~ github\.com[:/]+([^/]+)/([^/]+)$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
    printf '%s/%s' "$owner" "$repo"
    return 0
  fi
  return 1
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID_DIR="$ROOT/docs/devops/evidence"
mkdir -p "$EVID_DIR"

REPO=""
REQUIRED="SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD"
OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --required) REQUIRED="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_bin gh
require_bin jq

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPO:-}" ]; then
  REPO="$(infer_repo_from_git || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
if [ -z "${OUT:-}" ]; then
  # Include repo + pid + random to avoid collisions when running in parallel.
  repo_safe="$(printf '%s' "$REPO" | tr '/:' '__' | tr -cd 'A-Za-z0-9_.-')"
  OUT="$EVID_DIR/actions-secrets-check-${repo_safe}-${ts}-$$-$RANDOM.json"
fi

viewer_perm="$(gh repo view "$REPO" --json viewerPermission -q .viewerPermission 2>/dev/null || true)"

present_raw=""
set +e
present_raw="$(gh secret list -R "$REPO" --json name --jq '.[].name' 2>/dev/null)"
rc="$?"
set -e

if [ "$rc" -ne 0 ]; then
  jq -n \
    --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg repo "$REPO" \
    --arg viewer_permission "${viewer_perm:-}" \
    --argjson required "$(printf '%s\n' $REQUIRED | jq -R . | jq -s .)" \
    '{checked_at_utc:$checked_at_utc, repo:$repo, viewer_permission:$viewer_permission, can_list:false, required:$required, present:[], missing:$required, error:"Cannot list repo secrets (permission or auth issue)."}' \
    >"$OUT"
  echo "ERROR: cannot list GitHub Actions secrets for $REPO. Evidence: $OUT" >&2
  echo "Fix: ensure your token has Actions secrets read access (and repo access for private repos)." >&2
  exit 2
fi

# If there are zero secrets configured, gh returns an empty string; treat as [] (not [""]).
present_json="[]"
if [ -n "${present_raw:-}" ]; then
  present_json="$(printf '%s\n' "${present_raw:-}" | jq -R . | jq -s .)"
fi
missing_json="$(
  jq -n \
    --argjson present "$present_json" \
    --argjson required "$(printf '%s\n' $REQUIRED | jq -R . | jq -s .)" \
    '$required - $present'
)"

jq -n \
  --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg repo "$REPO" \
  --arg viewer_permission "${viewer_perm:-}" \
  --argjson required "$(printf '%s\n' $REQUIRED | jq -R . | jq -s .)" \
  --argjson present "$present_json" \
  --argjson missing "$missing_json" \
  '{checked_at_utc:$checked_at_utc, repo:$repo, viewer_permission:$viewer_permission, can_list:true, required:$required, present:$present, missing:$missing}' \
  >"$OUT"

missing_count="$(jq -r '(.missing // []) | length' "$OUT")"
if ! [[ "${missing_count:-}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: invalid secrets evidence JSON (missing_count=$missing_count). Evidence: $OUT" >&2
  exit 2
fi
if [ "$missing_count" -gt 0 ]; then
  echo "Missing secrets: $(jq -r '.missing | join(" ")' "$OUT")" >&2
  echo "Evidence: $OUT" >&2
  exit 2
fi

echo "All required secrets present. Evidence: $OUT" >&2
