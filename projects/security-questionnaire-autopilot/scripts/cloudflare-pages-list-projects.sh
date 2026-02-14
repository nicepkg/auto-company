#!/usr/bin/env bash
set -euo pipefail

# List Cloudflare Pages projects for an account.
#
# Required env:
#   CLOUDFLARE_API_TOKEN
#
# Optional env:
#   CLOUDFLARE_ACCOUNT_ID
#   CLOUDFLARE_ACCOUNT_NAME   (used when token can access multiple accounts)
#
# Output: tab-separated lines:
#   <project_name>\t<subdomain>\t<production_branch>

usage() {
  cat >&2 <<'EOF'
Usage:
  cloudflare-pages-list-projects.sh

Required env:
  CLOUDFLARE_API_TOKEN

Optional env:
  CLOUDFLARE_ACCOUNT_ID
  CLOUDFLARE_ACCOUNT_NAME

Example:
  export CLOUDFLARE_API_TOKEN="..."
  ./projects/security-questionnaire-autopilot/scripts/cloudflare-pages-list-projects.sh
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-${CF_ACCOUNT_ID:-}}"
CLOUDFLARE_ACCOUNT_NAME="${CLOUDFLARE_ACCOUNT_NAME:-${CF_ACCOUNT_NAME:-}}"

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Missing env: CLOUDFLARE_API_TOKEN" >&2
  usage
  exit 2
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

get_json() {
  local url="$1"
  curl -sS -m 20 "${auth[@]}" "${accept[@]}" "$url"
}

resolve_account_id() {
  if [ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    printf '%s' "${CLOUDFLARE_ACCOUNT_ID}"
    return 0
  fi

accounts_json="$(get_json "${api}/accounts" 2>/dev/null || true)"
if ! echo "$accounts_json" | jq -e 'type=="object" and (.success? == true) and (.result? | type=="array")' >/dev/null 2>&1; then
    echo "Cloudflare: failed to list accounts (cannot resolve CLOUDFLARE_ACCOUNT_ID)." >&2
    jq -e '.' >/dev/null 2>&1 <<<"$accounts_json" && echo "$accounts_json" | jq . >&2 || echo "$accounts_json" >&2
    exit 2
  fi

  count="$(echo "$accounts_json" | jq -r '.result | length' 2>/dev/null || echo "0")"
  if [ "$count" = "1" ]; then
    echo "$accounts_json" | jq -r '.result[0].id // empty' 2>/dev/null
    return 0
  fi

  if [ -n "${CLOUDFLARE_ACCOUNT_NAME:-}" ]; then
    echo "$accounts_json" | jq -r --arg name "${CLOUDFLARE_ACCOUNT_NAME}" '.result[]? | select(.name? == $name) | .id // empty' 2>/dev/null | head -n 1
    return 0
  fi

  echo "Cloudflare: token can access multiple accounts; set CLOUDFLARE_ACCOUNT_ID (or CLOUDFLARE_ACCOUNT_NAME)." >&2
  echo "Accounts visible to this token:" >&2
  echo "$accounts_json" | jq -r '.result[]? | "  - \(.name) (\(.id))"' >&2
  exit 2
}

acct_id="$(resolve_account_id)"
if [ -z "${acct_id:-}" ]; then
  exit 2
fi

page=1
per_page="${CF_PAGES_LIST_PER_PAGE:-100}"
while :; do
  url="${api}/accounts/${acct_id}/pages/projects?page=${page}&per_page=${per_page}"
  json="$(get_json "$url" 2>/dev/null || true)"
  if ! echo "$json" | jq -e 'type=="object" and (.success? == true) and (.result? | type=="array")' >/dev/null 2>&1; then
    echo "Cloudflare Pages: failed to list projects (account_id=${acct_id})." >&2
    jq -e '.' >/dev/null 2>&1 <<<"$json" && echo "$json" | jq . >&2 || echo "$json" >&2
    exit 2
  fi

  count="$(echo "$json" | jq -r '.result | length' 2>/dev/null || echo "0")"
  if [ "$count" = "0" ]; then
    break
  fi

  echo "$json" | jq -r '.result[]? | [(.name // ""), (.subdomain // ""), (.production_branch // .productionBranch // "" | (if type=="object" then (.name // "") else . end))] | @tsv'

  total_pages="$(echo "$json" | jq -r '.result_info.total_pages // .result_info.totalPages // empty' 2>/dev/null || true)"
  if [ -n "${total_pages:-}" ] && [ "$page" -ge "$total_pages" ]; then
    break
  fi
  page=$((page + 1))
done

