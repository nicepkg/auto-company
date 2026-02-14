#!/usr/bin/env bash
set -euo pipefail

# List Cloudflare accounts visible to an API token.
#
# Required env:
#   CLOUDFLARE_API_TOKEN
#
# Output (default): tab-separated lines:
#   <account_name>\t<account_id>

usage() {
  cat >&2 <<'EOF'
Usage:
  cloudflare-list-accounts.sh

Required env:
  CLOUDFLARE_API_TOKEN

Example:
  export CLOUDFLARE_API_TOKEN="..."
  ./projects/security-questionnaire-autopilot/scripts/cloudflare-list-accounts.sh
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
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

json="$(curl -sS -m 20 "${auth[@]}" "${accept[@]}" "${api}/accounts" 2>/dev/null || true)"
if ! echo "$json" | jq -e 'type=="object" and (.success? == true) and (.result? | type=="array")' >/dev/null 2>&1; then
  echo "Cloudflare: failed to list accounts." >&2
  jq -e '.' >/dev/null 2>&1 <<<"$json" && echo "$json" | jq . >&2 || echo "$json" >&2
  exit 2
fi

echo "$json" | jq -r '.result[]? | [(.name // ""), (.id // "")] | @tsv'

