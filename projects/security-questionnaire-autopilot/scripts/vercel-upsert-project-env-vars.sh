#!/usr/bin/env bash
set -euo pipefail

# Upsert environment variables on a Vercel project using the Vercel REST API.
#
# This script never prints secret values.
#
# Required env:
#   VERCEL_TOKEN
#   VERCEL_PROJECT_ID  OR  VERCEL_PROJECT
#
# Optional env (team-scoped projects):
#   VERCEL_TEAM_ID
#   VERCEL_TEAM_SLUG
#
# Inputs (env values to set):
#   NEXT_PUBLIC_SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#
# Optional controls:
#   VERCEL_ENV_TARGETS          Comma-separated list. Default: "production,preview"
#   VERCEL_SKIP_PREVIEW         If "1", omit preview target.
#
# API:
#   POST /v10/projects/{idOrName}/env?upsert=true

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "jq"

VERCEL_TOKEN="${VERCEL_TOKEN:-}"
VERCEL_PROJECT_ID="${VERCEL_PROJECT_ID:-}"
VERCEL_PROJECT="${VERCEL_PROJECT:-}"
VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-}"
VERCEL_TEAM_SLUG="${VERCEL_TEAM_SLUG:-}"

NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [ -z "${VERCEL_TOKEN}" ]; then
  echo "Missing env: VERCEL_TOKEN" >&2
  exit 2
fi

ID_OR_NAME="${VERCEL_PROJECT_ID:-${VERCEL_PROJECT}}"
if [ -z "${ID_OR_NAME}" ]; then
  echo "Missing env: VERCEL_PROJECT_ID or VERCEL_PROJECT" >&2
  exit 2
fi

if [ -z "${NEXT_PUBLIC_SUPABASE_URL}" ]; then
  echo "Missing env: NEXT_PUBLIC_SUPABASE_URL" >&2
  exit 2
fi
if [ -z "${SUPABASE_SERVICE_ROLE_KEY}" ]; then
  echo "Missing env: SUPABASE_SERVICE_ROLE_KEY" >&2
  exit 2
fi

targets_raw="${VERCEL_ENV_TARGETS:-production,preview}"
targets_raw="$(printf '%s' "$targets_raw" | tr -d ' ' | tr -s ',')"
targets_raw="${targets_raw#,}"
targets_raw="${targets_raw%,}"

IFS=',' read -r -a targets <<<"$targets_raw"
filtered_targets=()
for t in "${targets[@]}"; do
  [ -n "$t" ] || continue
  if [ "${VERCEL_SKIP_PREVIEW:-0}" = "1" ] && [ "$t" = "preview" ]; then
    continue
  fi
  filtered_targets+=("$t")
done

if [ "${#filtered_targets[@]}" -eq 0 ]; then
  echo "No Vercel env targets selected (VERCEL_ENV_TARGETS=${targets_raw})." >&2
  exit 2
fi

# "sensitive" variables are not permitted for the "development" target.
for t in "${filtered_targets[@]}"; do
  if [ "$t" = "development" ]; then
    echo "Refusing to set SUPABASE_SERVICE_ROLE_KEY for Vercel target=development (sensitive vars are not allowed)." >&2
    echo "Fix: remove development from VERCEL_ENV_TARGETS." >&2
    exit 2
  fi
done

api="https://api.vercel.com"
auth=(-H "Authorization: Bearer ${VERCEL_TOKEN}")
accept=(-H "Accept: application/json")
ct=(-H "Content-Type: application/json")

qs=""
if [ -n "${VERCEL_TEAM_ID}" ]; then
  qs="${qs}${qs:+&}teamId=${VERCEL_TEAM_ID}"
fi
if [ -n "${VERCEL_TEAM_SLUG}" ]; then
  qs="${qs}${qs:+&}slug=${VERCEL_TEAM_SLUG}"
fi
if [ -n "${qs}" ]; then
  qs="&${qs}"
fi

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

payload_public="${tmpdir}/payload-public.json"
payload_secret="${tmpdir}/payload-secret.json"

jq -n \
  --arg key "NEXT_PUBLIC_SUPABASE_URL" \
  --arg value "${NEXT_PUBLIC_SUPABASE_URL}" \
  --arg type "plain" \
  --argjson targets "$(printf '%s\n' "${filtered_targets[@]}" | jq -R . | jq -s .)" \
  --arg comment "cycle-005 hosted persistence: required for workflow runtime" \
  '{key:$key,value:$value,type:$type,target:$targets,comment:$comment}' \
  >"$payload_public"

jq -n \
  --arg key "SUPABASE_SERVICE_ROLE_KEY" \
  --arg value "${SUPABASE_SERVICE_ROLE_KEY}" \
  --arg type "sensitive" \
  --argjson targets "$(printf '%s\n' "${filtered_targets[@]}" | jq -R . | jq -s .)" \
  --arg comment "cycle-005 hosted persistence: required for workflow runtime" \
  '{key:$key,value:$value,type:$type,target:$targets,comment:$comment}' \
  >"$payload_secret"

post_env() {
  local payload_path="$1"
  local out_path="$2"
  local code
  code="$(
    curl -sS -m 20 -o "$out_path" -w "%{http_code}" \
      -X POST "${api}/v10/projects/${ID_OR_NAME}/env?upsert=true${qs}" \
      "${auth[@]}" "${accept[@]}" "${ct[@]}" \
      --data-binary "@${payload_path}" || echo "000"
  )"
  if [[ "$code" != 2* ]]; then
    echo "Vercel env upsert failed (HTTP ${code}) for project=${ID_OR_NAME}." >&2
    # Response should not include secret values for sensitive vars, but don't risk echoing it.
    exit 2
  fi
}

post_env "$payload_public" "${tmpdir}/resp-public.json"
post_env "$payload_secret" "${tmpdir}/resp-secret.json"

echo "Vercel env upsert ok: project=${ID_OR_NAME} targets=$(IFS=,; echo "${filtered_targets[*]}")" >&2

