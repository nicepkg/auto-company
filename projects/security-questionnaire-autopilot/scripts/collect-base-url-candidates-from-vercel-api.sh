#!/usr/bin/env bash
set -euo pipefail

# Collect candidate deployment base URLs from the Vercel REST API.
#
# Output: newline-separated URLs, normalized (no trailing slash).
#
# Best-effort behavior:
# - If required env vars are missing, prints nothing and exits 0.
# - If API calls fail, prints nothing and exits 0 unless STRICT=1.
#
# Required env:
#   VERCEL_TOKEN
#   VERCEL_PROJECT_ID  OR  VERCEL_PROJECT
#
# Optional env (team-scoped projects):
#   VERCEL_TEAM_ID
#   VERCEL_TEAM_SLUG   (aka "slug" in Vercel API docs)
#
# Notes:
# - Uses:
#   - GET /v9/projects/{idOrName}
#   - GET /v9/projects/{idOrName}/domains
#   - GET /v6/deployments?projectId=<id>

STRICT="${STRICT:-0}"

VERCEL_TOKEN="${VERCEL_TOKEN:-}"
VERCEL_PROJECT_ID="${VERCEL_PROJECT_ID:-}"
VERCEL_PROJECT="${VERCEL_PROJECT:-}"
VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-}"
VERCEL_TEAM_SLUG="${VERCEL_TEAM_SLUG:-}"

if [ -z "${VERCEL_TOKEN}" ]; then
  exit 0
fi

ID_OR_NAME="${VERCEL_PROJECT_ID:-${VERCEL_PROJECT}}"
if [ -z "${ID_OR_NAME}" ]; then
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

api="https://api.vercel.com"
auth=(-H "Authorization: Bearer ${VERCEL_TOKEN}")
accept=(-H "Accept: application/json")

qs=""
if [ -n "${VERCEL_TEAM_ID}" ]; then
  qs="${qs}${qs:+&}teamId=${VERCEL_TEAM_ID}"
fi
if [ -n "${VERCEL_TEAM_SLUG}" ]; then
  qs="${qs}${qs:+&}slug=${VERCEL_TEAM_SLUG}"
fi
if [ -n "${qs}" ]; then
  qs="?$qs"
fi

normalize_url() {
  local u="$1"
  u="${u%/}"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  # Keep scheme + host only.
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

project_json="$(
  get_json "${api}/v9/projects/${ID_OR_NAME}${qs}" 2>/dev/null || true
)"
if ! echo "$project_json" | jq -e 'type=="object" and (.id? | type=="string")' >/dev/null 2>&1; then
  if [ "$STRICT" = "1" ]; then
    echo "Vercel: failed to fetch project metadata for idOrName=${ID_OR_NAME}" >&2
    echo "$project_json" >&2
    exit 2
  fi
  exit 0
fi

project_id="$(echo "$project_json" | jq -r '.id // empty')"
if [ -z "$project_id" ]; then
  exit 0
fi

# Domains associated with the project (custom domains and/or vercel.app domains).
domains_json="$(
  get_json "${api}/v9/projects/${ID_OR_NAME}/domains${qs}" 2>/dev/null || true
)"
if echo "$domains_json" | jq -e 'type=="object" and (.domains? | type=="array")' >/dev/null 2>&1; then
  while IFS= read -r d; do
    [ -n "$d" ] && add_candidate "$d"
  done < <(echo "$domains_json" | jq -r '.domains[]?.name? // empty')
fi

# Deployments under the project (useful for preview/production *.vercel.app URLs).
limit="${VERCEL_DEPLOYMENTS_LIMIT:-10}"
target="${VERCEL_DEPLOYMENTS_TARGET:-production}"

deploy_qs="projectId=${project_id}&limit=${limit}&target=${target}"
if [ -n "${VERCEL_TEAM_ID}" ]; then
  deploy_qs="${deploy_qs}&teamId=${VERCEL_TEAM_ID}"
fi
if [ -n "${VERCEL_TEAM_SLUG}" ]; then
  deploy_qs="${deploy_qs}&slug=${VERCEL_TEAM_SLUG}"
fi

deployments_json="$(
  get_json "${api}/v6/deployments?${deploy_qs}" 2>/dev/null || true
)"
if echo "$deployments_json" | jq -e 'type=="object" and (.deployments? | type=="array")' >/dev/null 2>&1; then
  while IFS= read -r u; do
    [ -n "$u" ] && add_candidate "$u"
  done < <(echo "$deployments_json" | jq -r '.deployments[]?.url? // empty')
fi

for u in "${out[@]}"; do
  printf '%s\n' "$u"
done

