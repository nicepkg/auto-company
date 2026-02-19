#!/usr/bin/env bash
set -euo pipefail

# Ensure required GitHub Actions repo secrets exist for:
#   .github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml
#
# Required secrets (names only):
#   - SUPABASE_ACCESS_TOKEN
#   - SUPABASE_ORG_SLUG
#   - SUPABASE_DB_PASSWORD
#
# This script never prints secret values. It writes an evidence JSON report
# under docs/qa-bach/ by default.

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/gh-ensure-supabase-provision-secrets.sh [flags]

Flags:
  --repo OWNER/REPO        (default: inferred via gh)
  --check-only             Only check presence; do not set anything (default)
  --set-missing            Set missing secrets (values sourced from env or prompts)
  --non-interactive        Fail if a required value is missing from env (no prompts)
  --out-json PATH          Evidence JSON output path
  --out-log PATH           Evidence log output path

Env (used when --set-missing):
  SUPABASE_ACCESS_TOKEN
  SUPABASE_ORG_SLUG
  SUPABASE_DB_PASSWORD

Examples:
  # Check only (writes docs/qa-bach/* evidence)
  scripts/devops/gh-ensure-supabase-provision-secrets.sh --repo OWNER/REPO

  # Set missing secrets from env (non-interactive)
  SUPABASE_ACCESS_TOKEN=... SUPABASE_ORG_SLUG=... SUPABASE_DB_PASSWORD=... \
    scripts/devops/gh-ensure-supabase-provision-secrets.sh --repo OWNER/REPO --set-missing --non-interactive
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
MODE="check"
NON_INTERACTIVE="0"
OUT_JSON=""
OUT_LOG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --check-only) MODE="check"; shift 1 ;;
    --set-missing) MODE="set"; shift 1 ;;
    --non-interactive) NON_INTERACTIVE="1"; shift 1 ;;
    --out-json) OUT_JSON="${2:-}"; shift 2 ;;
    --out-log) OUT_LOG="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

gh auth status -h github.com >/dev/null

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

perm="$(gh repo view "$REPO" --json viewerPermission -q .viewerPermission 2>/dev/null || echo "")"
if [ "$MODE" = "set" ]; then
  case "$perm" in
    ADMIN|MAINTAIN|WRITE) ;;
    *)
      echo "Insufficient GitHub repo permission to set secrets." >&2
      echo "repo=$REPO viewerPermission=${perm:-unknown}" >&2
      echo "Fix: run as a maintainer (>= WRITE) or ask an admin to set secrets in the GitHub UI." >&2
      exit 2
      ;;
  esac
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ts="$(date -u +"%Y%m%dT%H%M%SZ")"
out_dir="$ROOT/docs/qa-bach"
mkdir -p "$out_dir"

if [ -z "${OUT_JSON:-}" ]; then
  repo_safe="$(printf '%s' "$REPO" | tr '/:' '__' | tr -cd 'A-Za-z0-9_.-')"
  OUT_JSON="$out_dir/cycle-018-gh-secrets-supabase-provision-${repo_safe}-${ts}-$$-$RANDOM.json"
fi
if [ -z "${OUT_LOG:-}" ]; then
  repo_safe="$(printf '%s' "$REPO" | tr '/:' '__' | tr -cd 'A-Za-z0-9_.-')"
  OUT_LOG="$out_dir/cycle-018-gh-secrets-supabase-provision-${repo_safe}-${ts}-$$-$RANDOM.log"
fi

log() {
  # Avoid leaking values; only print names + statuses.
  printf '%s\n' "$*" | tee -a "$OUT_LOG" >&2
}

api_get_secret_meta() {
  # Emits JSON on stdout (when exists), or empty string (when missing/forbidden).
  local name="$1"
  local tmp rc
  tmp="$(mktemp)"
  rc=0
  if ! gh api "repos/${REPO}/actions/secrets/${name}" >"$tmp" 2>>"$OUT_LOG"; then
    rc="$?"
  fi
  if [ "$rc" = "0" ]; then
    cat "$tmp"
  else
    cat /dev/null
  fi
  rm -f "$tmp" >/dev/null 2>&1 || true
}

secret_status() {
  # Prints one of: exists|missing|forbidden|unknown
  local name="$1"
  # gh api exit codes are not stable enough to interpret; detect HTTP codes from stderr.
  local tmp
  tmp="$(mktemp)"
  if gh api "repos/${REPO}/actions/secrets/${name}" > /dev/null 2>"$tmp"; then
    rm -f "$tmp" >/dev/null 2>&1 || true
    printf '%s' "exists"
    return 0
  fi
  if grep -q "HTTP 404" "$tmp" 2>/dev/null; then
    rm -f "$tmp" >/dev/null 2>&1 || true
    printf '%s' "missing"
    return 0
  fi
  if grep -q "HTTP 403" "$tmp" 2>/dev/null; then
    rm -f "$tmp" >/dev/null 2>&1 || true
    printf '%s' "forbidden"
    return 0
  fi
  rm -f "$tmp" >/dev/null 2>&1 || true
  printf '%s' "unknown"
}

prompt_value() {
  local name="$1"
  local secret="${2:-0}"
  local v=""
  if [ -n "${!name:-}" ]; then
    printf '%s' "${!name}"
    return 0
  fi
  if [ "$NON_INTERACTIVE" = "1" ]; then
    return 1
  fi
  if [ "$secret" = "1" ]; then
    read -r -s -p "Enter value for ${name}: " v </dev/tty
    echo "" >/dev/tty
  else
    read -r -p "Enter value for ${name}: " v </dev/tty
  fi
  if [ -z "${v:-}" ]; then
    return 1
  fi
  printf '%s' "$v"
}

required=(SUPABASE_ACCESS_TOKEN SUPABASE_ORG_SLUG SUPABASE_DB_PASSWORD)

log "repo=$REPO"
log "mode=$MODE"
log "evidence_json=$OUT_JSON"
log "evidence_log=$OUT_LOG"

report="$(jq -n \
  --arg repo "$REPO" \
  --arg checked_at_utc "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg mode "$MODE" \
  '{
    repo: $repo,
    checked_at_utc: $checked_at_utc,
    mode: $mode,
    secrets: {}
  }'
)"

missing_any="0"
for s in "${required[@]}"; do
  st="$(secret_status "$s")"
  case "$st" in
    exists)
      meta="$(api_get_secret_meta "$s" | jq -c '{name, created_at, updated_at}' 2>/dev/null || echo "")"
      report="$(jq --arg s "$s" --arg st "$st" --argjson meta "${meta:-null}" \
        '.secrets[$s] = {status:$st, exists:true, meta:$meta, action:"none", error:null}' <<<"$report")"
      log "secret $s: exists"
      ;;
    missing)
      report="$(jq --arg s "$s" --arg st "$st" \
        '.secrets[$s] = {status:$st, exists:false, meta:null, action:"none", error:null}' <<<"$report")"
      log "secret $s: missing"
      missing_any="1"
      ;;
    forbidden)
      report="$(jq --arg s "$s" --arg st "$st" \
        '.secrets[$s] = {status:$st, exists:null, meta:null, action:"none", error:"HTTP 403 (forbidden)"}' <<<"$report")"
      log "secret $s: cannot verify (HTTP 403)"
      ;;
    *)
      report="$(jq --arg s "$s" --arg st "$st" \
        '.secrets[$s] = {status:$st, exists:null, meta:null, action:"none", error:"unknown error checking secret"}' <<<"$report")"
      log "secret $s: cannot verify (unknown)"
      ;;
  esac
done

if [ "$MODE" = "set" ] && [ "$missing_any" = "1" ]; then
  for s in "${required[@]}"; do
    st="$(jq -r --arg s "$s" '.secrets[$s].status' <<<"$report")"
    if [ "$st" != "missing" ]; then
      continue
    fi

    secret_flag="0"
    case "$s" in
      SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD) secret_flag="1" ;;
    esac

    if ! v="$(prompt_value "$s" "$secret_flag")"; then
      report="$(jq --arg s "$s" \
        '.secrets[$s].action="failed" | .secrets[$s].error="missing value (set env or allow prompts)"' <<<"$report")"
      log "secret $s: cannot set (missing value)"
      continue
    fi

    log "secret $s: setting (value not printed)"
    if printf '%s' "$v" | gh secret set "$s" -R "$REPO" --app actions >>"$OUT_LOG" 2>&1; then
      # Refresh status (best-effort).
      st2="$(secret_status "$s")"
      report="$(jq --arg s "$s" --arg st2 "$st2" \
        '.secrets[$s].action="set" | .secrets[$s].status=$st2 | .secrets[$s].exists=true | .secrets[$s].error=null' <<<"$report")"
      log "secret $s: set"
    else
      report="$(jq --arg s "$s" \
        '.secrets[$s].action="failed" | .secrets[$s].error="gh secret set failed (see log)"' <<<"$report")"
      log "secret $s: set failed (see log)"
    fi
  done
fi

printf '%s\n' "$report" >"$OUT_JSON"

ok="$(jq -r '
  .secrets
  | to_entries
  | map(select(.value.status != "exists"))
  | length == 0
' "$OUT_JSON" 2>/dev/null || echo "false")"

if [ "$MODE" = "check" ]; then
  if [ "$ok" = "true" ]; then
    exit 0
  fi
  exit 2
fi

if [ "$ok" = "true" ]; then
  exit 0
fi
exit 2
