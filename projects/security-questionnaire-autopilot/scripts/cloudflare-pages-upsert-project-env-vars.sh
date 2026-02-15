#!/usr/bin/env bash
set -euo pipefail

# Upsert environment variables on a Cloudflare Pages project by patching deployment configs.
#
# This script never prints secret values.
#
# Required env:
#   CLOUDFLARE_API_TOKEN
#   CF_PAGES_PROJECT
#
# Optional env:
#   CLOUDFLARE_ACCOUNT_ID
#   CLOUDFLARE_ACCOUNT_NAME   (used when token can access multiple accounts)
#
# Inputs (env values to set):
#   NEXT_PUBLIC_SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#
# Notes:
# - Uses:
#   - GET  /client/v4/accounts/{account_id}/pages/projects/{project_name}
#   - PATCH /client/v4/accounts/{account_id}/pages/projects/{project_name}

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "jq"

CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-${CF_ACCOUNT_ID:-}}"
CLOUDFLARE_ACCOUNT_NAME="${CLOUDFLARE_ACCOUNT_NAME:-${CF_ACCOUNT_NAME:-}}"
CF_PAGES_PROJECT="${CF_PAGES_PROJECT:-${CF_PAGES_PROJECT_NAME:-}}"

NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [ -z "${CLOUDFLARE_API_TOKEN}" ] || [ -z "${CF_PAGES_PROJECT}" ]; then
  echo "Missing Cloudflare Pages config (CLOUDFLARE_API_TOKEN/CF_PAGES_PROJECT)." >&2
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

api="https://api.cloudflare.com/client/v4"
auth=(-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
accept=(-H "Accept: application/json")
ct=(-H "Content-Type: application/json")

get_json() {
  local url="$1"
  curl -sS -m 20 "${auth[@]}" "${accept[@]}" "$url"
}

resolve_account_id_for_pages_project() {
  # Best-effort: given CLOUDFLARE_API_TOKEN + CF_PAGES_PROJECT, locate the owning account id.
  local accounts_json count

  if [ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    printf '%s' "${CLOUDFLARE_ACCOUNT_ID}"
    return 0
  fi

  accounts_json="$(get_json "${api}/accounts" 2>/dev/null || true)"
  if ! echo "$accounts_json" | jq -e 'type=="object" and (.success? == true) and (.result? | type=="array")' >/dev/null 2>&1; then
    echo "Cloudflare: failed to list accounts (cannot resolve CLOUDFLARE_ACCOUNT_ID)." >&2
    exit 2
  fi

  # Prefer the account that owns CF_PAGES_PROJECT (token + project name should be enough).
  while IFS=$'\t' read -r aid aname; do
    [ -n "${aid:-}" ] || continue
    if [ -n "${CLOUDFLARE_ACCOUNT_NAME:-}" ] && [ "${aname:-}" != "${CLOUDFLARE_ACCOUNT_NAME}" ]; then
      continue
    fi
    proj_url="${api}/accounts/${aid}/pages/projects/${CF_PAGES_PROJECT}"
    proj_json="$(get_json "$proj_url" 2>/dev/null || true)"
    if echo "$proj_json" | jq -e 'type=="object" and (.success? == true)' >/dev/null 2>&1; then
      printf '%s' "$aid"
      return 0
    fi
  done < <(echo "$accounts_json" | jq -r '.result[]? | "\(.id)\t\(.name // \"\")"' 2>/dev/null || true)

  count="$(echo "$accounts_json" | jq -r '.result | length' 2>/dev/null || echo "0")"
  if [ "$count" = "1" ]; then
    echo "$accounts_json" | jq -r '.result[0].id // empty' 2>/dev/null
    return 0
  fi

  echo "Cloudflare: could not resolve CLOUDFLARE_ACCOUNT_ID for Pages project=${CF_PAGES_PROJECT}." >&2
  echo "Fix: set CLOUDFLARE_ACCOUNT_ID (or CLOUDFLARE_ACCOUNT_NAME to disambiguate), and ensure token scopes: Account:Read + Pages:Read + Pages:Edit." >&2
  exit 2
}

if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  CLOUDFLARE_ACCOUNT_ID="$(resolve_account_id_for_pages_project)"
fi

proj_url="${api}/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${CF_PAGES_PROJECT}"
proj_json="$(get_json "$proj_url" 2>/dev/null || true)"
if ! echo "$proj_json" | jq -e 'type=="object" and (.success? == true) and (.result? | type=="object")' >/dev/null 2>&1; then
  echo "Cloudflare Pages: failed to fetch project metadata (project=${CF_PAGES_PROJECT})." >&2
  exit 2
fi

existing_prod="$(echo "$proj_json" | jq -c '.result.deployment_configs.production.env_vars // {}')"
existing_prev="$(echo "$proj_json" | jq -c '.result.deployment_configs.preview.env_vars // {}')"

desired="$(jq -n \
  --arg url "${NEXT_PUBLIC_SUPABASE_URL}" \
  --arg key "${SUPABASE_SERVICE_ROLE_KEY}" \
  '{
    NEXT_PUBLIC_SUPABASE_URL: { value: $url, type: "plain_text" },
    SUPABASE_SERVICE_ROLE_KEY: { value: $key, type: "secret_text" }
  }'
)"

merged_prod="$(jq -n --argjson a "$existing_prod" --argjson b "$desired" '$a * $b')"
merged_prev="$(jq -n --argjson a "$existing_prev" --argjson b "$desired" '$a * $b')"

payload="$(jq -n \
  --argjson prod "$merged_prod" \
  --argjson prev "$merged_prev" \
  '{deployment_configs:{production:{env_vars:$prod},preview:{env_vars:$prev}}}'
)"

tmp_payload="$(mktemp)"
trap 'rm -f "$tmp_payload"' EXIT
printf '%s' "$payload" >"$tmp_payload"

code="$(
  curl -sS -m 30 -o /tmp/cf-pages-patch.json -w "%{http_code}" \
    -X PATCH "${proj_url}" \
    "${auth[@]}" "${accept[@]}" "${ct[@]}" \
    --data-binary "@${tmp_payload}" || echo "000"
)"
if [[ "$code" != 2* ]]; then
  echo "Cloudflare Pages env patch failed (HTTP ${code}) for project=${CF_PAGES_PROJECT}." >&2
  exit 2
fi

echo "Cloudflare Pages env upsert ok: project=${CF_PAGES_PROJECT} (production+preview)" >&2
