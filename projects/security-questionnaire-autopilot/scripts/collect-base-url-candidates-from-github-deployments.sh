#!/usr/bin/env bash
set -euo pipefail

# Collect candidate deployment base URLs from GitHub Deployments metadata.
#
# Output: newline-separated URLs, normalized (no trailing slash).
#
# Notes:
# - Many repos do NOT publish GitHub Deployments metadata. In that case, this prints nothing and exits 0.
# - Intended to be used as a best-effort helper for Cycle 005 BASE_URL discovery.

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Missing env var: $name" >&2
    exit 2
  fi
}

normalize_url() {
  local u="$1"
  u="${u%/}"
  printf '%s' "$u"
}

require_bin "curl"
require_bin "jq"

require_env "GITHUB_REPOSITORY"
require_env "GITHUB_TOKEN"

API="https://api.github.com"
PER_PAGE="${PER_PAGE:-20}"
MAX_CANDIDATES="${MAX_CANDIDATES:-6}"

hdr_auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
hdr_json=(-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")

deployments_json="$(
  curl -sS "${hdr_auth[@]}" "${hdr_json[@]}" \
    "$API/repos/${GITHUB_REPOSITORY}/deployments?per_page=${PER_PAGE}" || true
)"

# If the API returns an error object, treat as empty (best-effort helper).
if ! echo "$deployments_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
  exit 0
fi

dep_count="$(echo "$deployments_json" | jq 'length')"
if [ "${dep_count:-0}" -lt 1 ]; then
  exit 0
fi

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

# Optional filters:
# - DEPLOYMENT_ENVIRONMENT: match Deployment.environment
# - DEPLOYMENT_REF: match Deployment.ref
DEPLOYMENT_ENVIRONMENT="${DEPLOYMENT_ENVIRONMENT:-}"
DEPLOYMENT_REF="${DEPLOYMENT_REF:-}"

for i in $(seq 0 $((dep_count - 1))); do
  dep_id="$(echo "$deployments_json" | jq -r ".[$i].id // empty")"
  dep_env="$(echo "$deployments_json" | jq -r ".[$i].environment // empty")"
  dep_ref="$(echo "$deployments_json" | jq -r ".[$i].ref // empty")"

  if [ -z "$dep_id" ]; then
    continue
  fi
  if [ -n "$DEPLOYMENT_ENVIRONMENT" ] && [ "$dep_env" != "$DEPLOYMENT_ENVIRONMENT" ]; then
    continue
  fi
  if [ -n "$DEPLOYMENT_REF" ] && [ "$dep_ref" != "$DEPLOYMENT_REF" ]; then
    continue
  fi

  statuses_json="$(
    curl -sS "${hdr_auth[@]}" "${hdr_json[@]}" \
      "$API/repos/${GITHUB_REPOSITORY}/deployments/${dep_id}/statuses?per_page=10" || true
  )"
  if ! echo "$statuses_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    continue
  fi

  # Prefer environment_url (meant to be user-facing) but also include target_url
  # because some providers populate only that field.
  while IFS= read -r u; do
    [ -n "$u" ] && add_candidate "$u"
  done < <(echo "$statuses_json" | jq -r '.[] | .environment_url? // empty')

  while IFS= read -r u; do
    [ -n "$u" ] && add_candidate "$u"
  done < <(echo "$statuses_json" | jq -r '.[] | .target_url? // empty')

  if [ "${#out[@]}" -ge "$MAX_CANDIDATES" ]; then
    break
  fi
done

for u in "${out[@]:0:$MAX_CANDIDATES}"; do
  printf '%s\n' "$u"
done

