#!/usr/bin/env bash
set -euo pipefail

# Set GitHub Actions secrets (via gh) without printing secret values.
# Intended for a small required set; prompts for missing values unless --non-interactive.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/gha-secrets-set.sh [flags]

Flags:
  --repo OWNER/REPO        (default: inferred via gh or git remote)
  --required "A B C"       (default: SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD)
  --only-missing           (default: true) only prompt/set secrets that are missing
  --non-interactive        fail if required values are not present as env vars (no prompting)
  --out PATH               (default: docs/devops/evidence/actions-secrets-set-<ts>.json)

Value sources:
  - For each secret NAME, this script reads env var NAME.
  - If missing (and interactive), it prompts securely (no echo).

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

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVID_DIR="$ROOT/docs/devops/evidence"
mkdir -p "$EVID_DIR"

REPO=""
REQUIRED="SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD"
ONLY_MISSING="1"
NON_INTERACTIVE="0"
OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --required) REQUIRED="${2:-}"; shift 2 ;;
    --only-missing) ONLY_MISSING="1"; shift 1 ;;
    --non-interactive) NON_INTERACTIVE="1"; shift 1 ;;
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
  REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#\\.git$##' | sed -E 's#.*github\\.com[:/]+([^/]+/[^/]+)$#\\1#' || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
if [ -z "${OUT:-}" ]; then
  # Include repo + pid + random to avoid collisions when running in parallel.
  repo_safe="$(printf '%s' "$REPO" | tr '/:' '__' | tr -cd 'A-Za-z0-9_.-')"
  OUT="$EVID_DIR/actions-secrets-set-${repo_safe}-${ts}-$$-$RANDOM.json"
fi

target_required_json="$(printf '%s\n' $REQUIRED | jq -R . | jq -s .)"
target_names=($REQUIRED)

if [ "$ONLY_MISSING" = "1" ]; then
  check_json="$("$ROOT/scripts/devops/gha-secrets-verify.sh" --repo "$REPO" --required "$REQUIRED" --out "$EVID_DIR/.tmp-actions-secrets-check-$ts.json" 2>/dev/null || true)"
  # Read missing list even if verify exited non-zero.
  missing_list="$(jq -r '.missing[]? // empty' "$EVID_DIR/.tmp-actions-secrets-check-$ts.json" 2>/dev/null || true)"
  if [ -n "${missing_list:-}" ]; then
    target_names=($missing_list)
    target_required_json="$(printf '%s\n' $missing_list | jq -R . | jq -s .)"
  else
    target_names=()
    target_required_json="[]"
  fi
fi

set_names=()
sources_json='{}'

for name in "${target_names[@]:-}"; do
  [ -n "${name:-}" ] || continue
  val="${!name:-}"
  src="env"
  if [ -z "${val:-}" ]; then
    if [ "$NON_INTERACTIVE" = "1" ]; then
      echo "Missing env var for secret $name (non-interactive mode)." >&2
      exit 2
    fi
    read -rs -p "$name: " val
    echo >&2
    src="prompt"
  fi

  # Do not print secret values; set via stdin.
  printf '%s' "$val" | gh secret set "$name" -R "$REPO" >/dev/null
  set_names+=("$name")
  sources_json="$(jq -c --arg k "$name" --arg v "$src" '. + {($k): $v}' <<<"$sources_json")"
done

jq -n \
  --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg repo "$REPO" \
  --argjson required "$target_required_json" \
  --argjson set "$(printf '%s\n' "${set_names[@]:-}" | jq -R . | jq -s .)" \
  --argjson sources "$sources_json" \
  '{checked_at_utc:$checked_at_utc, repo:$repo, required:$required, set:$set, sources:$sources}' \
  >"$OUT"

echo "Secrets set (names only): ${set_names[*]:-<none>}" >&2
echo "Evidence: $OUT" >&2
