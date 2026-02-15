#!/usr/bin/env bash
set -euo pipefail

# List Vercel projects visible to a token (optionally team-scoped).
#
# Required env:
#   VERCEL_TOKEN
#
# Optional env (team-scoped projects):
#   VERCEL_TEAM_ID
#   VERCEL_TEAM_SLUG
#
# Output: tab-separated lines:
#   <project_name>\t<project_id>\t<framework>

usage() {
  cat >&2 <<'EOF'
Usage:
  vercel-list-projects.sh

Required env:
  VERCEL_TOKEN

Optional env:
  VERCEL_TEAM_ID
  VERCEL_TEAM_SLUG

Example:
  export VERCEL_TOKEN="..."
  ./projects/security-questionnaire-autopilot/scripts/vercel-list-projects.sh
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

VERCEL_TOKEN="${VERCEL_TOKEN:-}"
VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-}"
VERCEL_TEAM_SLUG="${VERCEL_TEAM_SLUG:-}"
LIMIT="${VERCEL_PROJECTS_LIMIT:-100}"

if [ -z "${VERCEL_TOKEN:-}" ]; then
  echo "Missing env: VERCEL_TOKEN" >&2
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

api="https://api.vercel.com"
auth=(-H "Authorization: Bearer ${VERCEL_TOKEN}")
accept=(-H "Accept: application/json")

qs="limit=${LIMIT}"
if [ -n "${VERCEL_TEAM_ID:-}" ]; then
  qs="${qs}&teamId=${VERCEL_TEAM_ID}"
fi
if [ -n "${VERCEL_TEAM_SLUG:-}" ]; then
  qs="${qs}&slug=${VERCEL_TEAM_SLUG}"
fi

json="$(curl -sS -m 20 "${auth[@]}" "${accept[@]}" "${api}/v9/projects?${qs}" 2>/dev/null || true)"
if ! echo "$json" | jq -e 'type=="object"' >/dev/null 2>&1; then
  echo "Vercel: failed to list projects (non-JSON response)." >&2
  echo "$json" >&2
  exit 2
fi

# Some Vercel API responses use "projects". Be defensive.
if ! echo "$json" | jq -e '(.projects? | type=="array")' >/dev/null 2>&1; then
  # If the API returned an error object, surface it.
  if echo "$json" | jq -e '(.error? | type=="object") or (.message? | type=="string")' >/dev/null 2>&1; then
    echo "Vercel: error listing projects:" >&2
    echo "$json" | jq . >&2 || true
    exit 2
  fi
  echo "Vercel: unexpected response shape from /v9/projects." >&2
  echo "$json" | jq . >&2 || true
  exit 2
fi

echo "$json" | jq -r '.projects[]? | [(.name // ""), (.id // ""), (.framework // "")] | @tsv'

