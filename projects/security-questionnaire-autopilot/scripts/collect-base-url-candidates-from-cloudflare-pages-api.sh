#!/usr/bin/env bash
set -euo pipefail

# Collect candidate deployment base URLs from the Cloudflare Pages REST API.
#
# Output: newline-separated URLs, normalized (no trailing slash).
#
# Best-effort behavior:
# - If required env vars are missing, prints nothing and exits 0.
# - If API calls fail, prints nothing and exits 0 unless STRICT=1.
#
# Required env:
#   CLOUDFLARE_API_TOKEN
#   CLOUDFLARE_ACCOUNT_ID
#   CF_PAGES_PROJECT
#
# Notes:
# - Uses:
#   - GET /client/v4/accounts/{account_id}/pages/projects/{project_name}
#   - GET /client/v4/accounts/{account_id}/pages/projects/{project_name}/domains

STRICT="${STRICT:-0}"

CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"
CF_PAGES_PROJECT="${CF_PAGES_PROJECT:-}"

if [ -z "${CLOUDFLARE_API_TOKEN}" ] || [ -z "${CLOUDFLARE_ACCOUNT_ID}" ] || [ -z "${CF_PAGES_PROJECT}" ]; then
  exit 0
fi

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "jq"

api="https://api.cloudflare.com/client/v4"
auth=(-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
accept=(-H "Accept: application/json")

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
out=()

add_candidate() {
  local u="$1"
  u="$(normalize_url "$u")"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    return 0
  fi
  if [ -n "${seen[$u]+x}" ]; then
    return 0
  fi
  seen["$u"]=1
  out+=("$u")
}

get_json() {
  local url="$1"
  curl -sS -m 15 "${auth[@]}" "${accept[@]}" "$url"
}

proj_url="${api}/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${CF_PAGES_PROJECT}"
proj_json="$(get_json "$proj_url" 2>/dev/null || true)"
if ! echo "$proj_json" | jq -e 'type=="object" and (.success? == true)' >/dev/null 2>&1; then
  if [ "$STRICT" = "1" ]; then
    echo "Cloudflare Pages: failed to fetch project: ${CF_PAGES_PROJECT}" >&2
    echo "$proj_json" >&2
    exit 2
  fi
  exit 0
fi

# Default pages.dev hostname often appears as result.subdomain, e.g. "myproj.pages.dev"
subdomain="$(echo "$proj_json" | jq -r '.result.subdomain? // empty' 2>/dev/null || true)"
if [ -n "$subdomain" ]; then
  add_candidate "$subdomain"
fi

# Some responses include domains on the project itself.
while IFS= read -r d; do
  [ -n "$d" ] && add_candidate "$d"
done < <(echo "$proj_json" | jq -r '.result.domains[]? // empty' 2>/dev/null || true)

# Explicit domains endpoint for the project.
domains_url="${api}/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${CF_PAGES_PROJECT}/domains"
domains_json="$(get_json "$domains_url" 2>/dev/null || true)"
if echo "$domains_json" | jq -e 'type=="object" and (.success? == true) and (.result? | type=="array")' >/dev/null 2>&1; then
  # Cloudflare has used "name" in docs/examples; keep a couple fallbacks to be safe.
  while IFS= read -r d; do
    [ -n "$d" ] && add_candidate "$d"
  done < <(echo "$domains_json" | jq -r '.result[]? | (.name? // .domain? // .hostname? // empty)' 2>/dev/null || true)
fi

for u in "${out[@]}"; do
  printf '%s\n' "$u"
done

