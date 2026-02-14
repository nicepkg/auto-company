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
#   - GET /v2/deployments/{deploymentId}/aliases   (best-effort; improves branch/preview URL coverage)

STRICT="${STRICT:-0}"

VERCEL_TOKEN="${VERCEL_TOKEN:-}"
VERCEL_PROJECT_ID="${VERCEL_PROJECT_ID:-}"
VERCEL_PROJECT="${VERCEL_PROJECT:-${VERCEL_PROJECT_NAME:-}}"
VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-}"
VERCEL_TEAM_SLUG="${VERCEL_TEAM_SLUG:-}"
VERCEL_DEPLOYMENTS_TARGETS="${VERCEL_DEPLOYMENTS_TARGETS:-}"

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

EFFECTIVE_TEAM_ID="${VERCEL_TEAM_ID:-}"
EFFECTIVE_TEAM_SLUG="${VERCEL_TEAM_SLUG:-}"
build_qs() {
  local q=""
  if [ -n "${EFFECTIVE_TEAM_ID:-}" ]; then
    q="${q}${q:+&}teamId=${EFFECTIVE_TEAM_ID}"
  fi
  if [ -n "${EFFECTIVE_TEAM_SLUG:-}" ]; then
    q="${q}${q:+&}slug=${EFFECTIVE_TEAM_SLUG}"
  fi
  if [ -n "${q}" ]; then
    printf '?%s' "$q"
    return 0
  fi
  printf '%s' ""
}
qs="$(build_qs)"

normalize_url() {
  local u="$1"
  u="${u%/}"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  # Keep scheme + host only.
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\1#')"
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
  # Reduce maintainer config burden: if a token can access multiple teams, try to resolve the
  # owning team automatically when VERCEL_TEAM_ID/VERCEL_TEAM_SLUG are not provided.
  if [ -z "${EFFECTIVE_TEAM_ID:-}" ] && [ -z "${EFFECTIVE_TEAM_SLUG:-}" ]; then
    teams_json="$(get_json "${api}/v2/teams?limit=100" 2>/dev/null || true)"
    if echo "$teams_json" | jq -e 'type=="object" and (.teams? | type=="array")' >/dev/null 2>&1; then
      while IFS=$'\t' read -r tid tslug; do
        [ -n "${tid:-}" ] || continue
        EFFECTIVE_TEAM_ID="$tid"
        EFFECTIVE_TEAM_SLUG="${tslug:-}"
        qs="$(build_qs)"
        project_json="$(get_json "${api}/v9/projects/${ID_OR_NAME}${qs}" 2>/dev/null || true)"
        if echo "$project_json" | jq -e 'type=="object" and (.id? | type=="string")' >/dev/null 2>&1; then
          break
        fi
      done < <(echo "$teams_json" | jq -r '.teams[]? | "\(.id // \"\")\t\(.slug // \"\")"' 2>/dev/null || true)
    fi
  fi

  if ! echo "$project_json" | jq -e 'type=="object" and (.id? | type=="string")' >/dev/null 2>&1; then
    if [ "$STRICT" = "1" ]; then
      echo "Vercel: failed to fetch project metadata for idOrName=${ID_OR_NAME}" >&2
      echo "$project_json" >&2
      exit 2
    fi
    exit 0
  fi
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
target_single="${VERCEL_DEPLOYMENTS_TARGET:-}"
targets="${VERCEL_DEPLOYMENTS_TARGETS:-}"
if [ -n "${target_single:-}" ] && [ -z "${targets:-}" ]; then
  targets="$target_single"
fi
if [ -z "${targets:-}" ]; then
  targets="production,preview"
fi

scan_alias_limit="${VERCEL_DEPLOYMENTS_ALIAS_SCAN_LIMIT:-6}"
alias_scanned=0

fetch_deploy_aliases() {
  # Args: deployment_id (uid)
  local did="$1"
  local a_json
  [ -n "${did:-}" ] || return 0

  a_json="$(get_json "${api}/v2/deployments/${did}/aliases${qs}" 2>/dev/null || true)"
  if ! echo "$a_json" | jq -e 'type=="object" and (.aliases? | type=="array")' >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r a; do
    [ -n "$a" ] && add_candidate "$a"
  done < <(echo "$a_json" | jq -r '.aliases[]? | (.alias? // .hostname? // .name? // .domain? // (if type=="string" then . else empty end) // empty)' 2>/dev/null || true)
}

IFS=',' read -r -a _targets <<<"$(printf '%s' "$targets" | tr -s ' ' | tr ' ' ',' )"
for target in "${_targets[@]:-}"; do
  target="$(printf '%s' "${target:-}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -n "${target:-}" ] || continue

  deploy_qs="projectId=${project_id}&limit=${limit}&target=${target}"
  if [ -n "${EFFECTIVE_TEAM_ID:-}" ]; then
    deploy_qs="${deploy_qs}&teamId=${EFFECTIVE_TEAM_ID}"
  fi
  if [ -n "${EFFECTIVE_TEAM_SLUG:-}" ]; then
    deploy_qs="${deploy_qs}&slug=${EFFECTIVE_TEAM_SLUG}"
  fi

  deployments_json="$(
    get_json "${api}/v6/deployments?${deploy_qs}" 2>/dev/null || true
  )"
  if ! echo "$deployments_json" | jq -e 'type=="object" and (.deployments? | type=="array")' >/dev/null 2>&1; then
    if [ "$STRICT" = "1" ]; then
      echo "Vercel: failed to list deployments for target=${target}" >&2
      echo "$deployments_json" >&2
      exit 2
    fi
    continue
  fi

  # Add deployment URL + any inline aliases if present.
  while IFS= read -r u; do
    [ -n "$u" ] && add_candidate "$u"
  done < <(
    echo "$deployments_json" | jq -r '
      .deployments[]? |
        (.url? // empty),
        (.aliases[]? // empty),
        (.alias[]? // empty)
    ' 2>/dev/null || true
  )

  # Best-effort: fetch alias list for a small number of deployments to get branch URLs.
  if [ "${scan_alias_limit:-0}" -gt 0 ] && [ "$alias_scanned" -lt "$scan_alias_limit" ]; then
    remaining="$((scan_alias_limit - alias_scanned))"
    while IFS= read -r did; do
      [ -n "$did" ] || continue
      fetch_deploy_aliases "$did"
      alias_scanned=$((alias_scanned + 1))
      if [ "$alias_scanned" -ge "$scan_alias_limit" ]; then
        break
      fi
    done < <(echo "$deployments_json" | jq -r '.deployments[]? | (.uid? // .id? // empty)' 2>/dev/null | head -n "$remaining")
  fi
done

for u in "${out[@]}"; do
  printf '%s\n' "$u"
done
