#!/usr/bin/env bash
set -euo pipefail

# Collect candidate hosted workflow base URLs from hosting provider APIs.
#
# Output: newline-separated URLs, normalized (no trailing slash).
#
# Best-effort: providers that are not configured (missing env) simply output nothing.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$ROOT/projects/security-questionnaire-autopilot/scripts"

normalize_url() {
  local u="$1"
  u="${u%/}"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\\1#')"
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

while IFS= read -r u; do
  [ -n "$u" ] && add "$u"
done < <(
  "$SCRIPTS_DIR/collect-base-url-candidates-from-vercel-api.sh" 2>/dev/null || true
  "$SCRIPTS_DIR/collect-base-url-candidates-from-cloudflare-pages-api.sh" 2>/dev/null || true
)

