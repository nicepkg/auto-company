#!/usr/bin/env bash
set -euo pipefail

# Collect candidate hosted workflow base URLs from hosting provider APIs.
#
# Output: newline-separated URLs, normalized (no trailing slash).
#
# Best-effort: providers that are not configured (missing env) simply output nothing.
#
# Optional diagnostics:
# - HOSTING_DISCOVERY_DIAG=1: do not silence provider stderr
# - HOSTING_DISCOVERY_STRICT=1: pass STRICT=1 to providers (they will print actionable errors)

# Repo root (this script lives in projects/security-questionnaire-autopilot/scripts).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="$ROOT/projects/security-questionnaire-autopilot/scripts"

HOSTING_DISCOVERY_DIAG="${HOSTING_DISCOVERY_DIAG:-0}"
HOSTING_DISCOVERY_STRICT="${HOSTING_DISCOVERY_STRICT:-0}"

normalize_url() {
  local u="$1"
  u="${u%/}"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\1#')"
  u="${u%/}"
  printf '%s' "$u"
}

declare -A seen
add() {
  local u="$1"
  u="$(normalize_url "$u")"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    return 0
  fi
  if [ -n "${seen[$u]+x}" ]; then
    return 0
  fi
  seen["$u"]=1
  printf '%s\n' "$u"
}

run_provider() {
  local script="$1"
  if [ "${HOSTING_DISCOVERY_STRICT}" = "1" ]; then
    if [ "${HOSTING_DISCOVERY_DIAG}" = "1" ]; then
      STRICT=1 "$script" || true
    else
      STRICT=1 "$script" 2>/dev/null || true
    fi
    return 0
  fi

  if [ "${HOSTING_DISCOVERY_DIAG}" = "1" ]; then
    "$script" || true
  else
    "$script" 2>/dev/null || true
  fi
}

while IFS= read -r u; do
  [ -n "$u" ] && add "$u"
done < <(
  run_provider "$SCRIPTS_DIR/collect-base-url-candidates-from-vercel-api.sh"
  run_provider "$SCRIPTS_DIR/collect-base-url-candidates-from-cloudflare-pages-api.sh"
)
