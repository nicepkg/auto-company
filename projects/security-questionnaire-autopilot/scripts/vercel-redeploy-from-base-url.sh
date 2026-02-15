#!/usr/bin/env bash
set -euo pipefail

# Trigger a Vercel redeploy (best-effort) using the REST API.
#
# Usage:
#   vercel-redeploy-from-base-url.sh <BASE_URL>
#
# Required env:
#   VERCEL_TOKEN
#
# Optional env (team-scoped projects):
#   VERCEL_TEAM_ID
#   VERCEL_TEAM_SLUG
#
# Optional env (fallbacks):
#   VERCEL_PROJECT_ID or VERCEL_PROJECT   (if set, can fall back to latest production deployment)
#   VERCEL_DEPLOY_HOOK_URL               (if set, can fall back to deploy hook)
#
# Notes:
# - This is best-effort. If it cannot resolve a deployment id for BASE_URL, it exits non-zero
#   with a remediation message (manual redeploy in Vercel UI is acceptable).

BASE_URL="${1:-}"

VERCEL_TOKEN="${VERCEL_TOKEN:-}"
VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-}"
VERCEL_TEAM_SLUG="${VERCEL_TEAM_SLUG:-}"
VERCEL_PROJECT_ID="${VERCEL_PROJECT_ID:-}"
VERCEL_PROJECT="${VERCEL_PROJECT:-}"
VERCEL_DEPLOY_HOOK_URL="${VERCEL_DEPLOY_HOOK_URL:-}"

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "curl"
require_bin "jq"

if [ -z "${BASE_URL}" ]; then
  echo "Usage: vercel-redeploy-from-base-url.sh <BASE_URL>" >&2
  exit 2
fi

if [ -z "${VERCEL_TOKEN}" ]; then
  echo "Missing env: VERCEL_TOKEN" >&2
  exit 2
fi

host="$(printf '%s' "$BASE_URL" | sed -E 's#^https?://##; s#/.*$##')"
if [ -z "$host" ]; then
  echo "Could not parse host from BASE_URL: $BASE_URL" >&2
  exit 2
fi

api="https://api.vercel.com"
auth=(-H "Authorization: Bearer ${VERCEL_TOKEN}")
accept=(-H "Accept: application/json")
ctype=(-H "Content-Type: application/json")

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

echo "Vercel: resolving deployment for host=${host} ..." >&2
tmp="$(mktemp)"
code="$(
  curl -sS -m 20 -o "$tmp" -w "%{http_code}" \
    -X GET "${auth[@]}" "${accept[@]}" \
    "${api}/v13/deployments/${host}${qs}" || echo "000"
)"

if [ "$code" != "200" ]; then
  echo "Vercel: could not resolve deployment from BASE_URL (HTTP $code): ${api}/v13/deployments/${host}" >&2
  rm -f "$tmp" 2>/dev/null || true

  # Fallback 1: if project id/name is available, redeploy latest production deployment for that project.
  ID_OR_NAME="${VERCEL_PROJECT_ID:-${VERCEL_PROJECT}}"
  if [ -n "${ID_OR_NAME:-}" ]; then
    echo "Vercel: fallback redeploy via project=${ID_OR_NAME} (latest production deployment)..." >&2

    project_json="$(curl -sS -m 20 "${auth[@]}" "${accept[@]}" "${api}/v9/projects/${ID_OR_NAME}${qs}" 2>/dev/null || true)"
    project_id="$(echo "$project_json" | jq -r '.id // empty' 2>/dev/null || true)"
    if [ -n "${project_id:-}" ]; then
      deploy_qs="projectId=${project_id}&limit=1&target=production"
      if [ -n "${VERCEL_TEAM_ID}" ]; then
        deploy_qs="${deploy_qs}&teamId=${VERCEL_TEAM_ID}"
      fi
      if [ -n "${VERCEL_TEAM_SLUG}" ]; then
        deploy_qs="${deploy_qs}&slug=${VERCEL_TEAM_SLUG}"
      fi
      deployments_json="$(curl -sS -m 20 "${auth[@]}" "${accept[@]}" "${api}/v6/deployments?${deploy_qs}" 2>/dev/null || true)"
      deployment_id="$(echo "$deployments_json" | jq -r '.deployments[0].uid // .deployments[0].id // empty' 2>/dev/null || true)"
      if [ -n "${deployment_id:-}" ]; then
        echo "Vercel: triggering redeploy (deploymentId=${deployment_id}) ..." >&2
        payload="$(jq -n --arg did "$deployment_id" '{deploymentId:$did, withLatestCommit:true, target:"production"}')"
        tmp2="$(mktemp)"
        code2="$(
          curl -sS -m 30 -o "$tmp2" -w "%{http_code}" \
            -X POST "${auth[@]}" "${accept[@]}" "${ctype[@]}" \
            --data-binary "$payload" \
            "${api}/v13/deployments${qs}" || echo "000"
        )"
        if [ "$code2" = "200" ] || [ "$code2" = "201" ]; then
          new_url="$(jq -r '.url // empty' "$tmp2" 2>/dev/null || true)"
          new_id="$(jq -r '.id // .uid // empty' "$tmp2" 2>/dev/null || true)"
          rm -f "$tmp2" 2>/dev/null || true
          if [ -n "$new_url" ]; then
            echo "Vercel: redeploy triggered: https://${new_url} (id=${new_id:-unknown})" >&2
          else
            echo "Vercel: redeploy triggered (id=${new_id:-unknown})." >&2
          fi
          exit 0
        fi
        rm -f "$tmp2" 2>/dev/null || true
      fi
    fi
  fi

  # Fallback 2: deploy hook (if present).
  if [ -n "${VERCEL_DEPLOY_HOOK_URL:-}" ]; then
    echo "Vercel: fallback redeploy via deploy hook..." >&2
    hook_code="$(curl -sS -m 20 -o /dev/null -w "%{http_code}" -X POST "${VERCEL_DEPLOY_HOOK_URL}" || echo "000")"
    if [ "$hook_code" = "200" ] || [ "$hook_code" = "201" ] || [ "$hook_code" = "204" ]; then
      echo "Vercel: redeploy triggered via deploy hook." >&2
      exit 0
    fi
    echo "Vercel: deploy hook failed (HTTP $hook_code)." >&2
  fi

  echo "" >&2
  echo "Remediation: redeploy the Vercel project manually (Project -> Deployments -> Redeploy)." >&2
  exit 2
fi

deployment_id="$(jq -r '.id // .uid // empty' "$tmp" 2>/dev/null || true)"
deployment_url="$(jq -r '.url // empty' "$tmp" 2>/dev/null || true)"
rm -f "$tmp" 2>/dev/null || true

if [ -z "$deployment_id" ]; then
  echo "Vercel: deployment lookup did not include an id/uid; cannot redeploy automatically." >&2
  echo "Remediation: redeploy the Vercel project manually (Project -> Deployments -> Redeploy)." >&2
  exit 2
fi

echo "Vercel: triggering redeploy (deploymentId=${deployment_id}) ..." >&2

payload="$(jq -n --arg did "$deployment_id" '{deploymentId:$did, withLatestCommit:true, target:"production"}')"
tmp="$(mktemp)"
code="$(
  curl -sS -m 30 -o "$tmp" -w "%{http_code}" \
    -X POST "${auth[@]}" "${accept[@]}" "${ctype[@]}" \
    --data-binary "$payload" \
    "${api}/v13/deployments${qs}" || echo "000"
)"

if [ "$code" != "200" ] && [ "$code" != "201" ]; then
  echo "Vercel: redeploy request failed (HTTP $code)." >&2
  jq -e '.' "$tmp" >/dev/null 2>&1 && jq . "$tmp" >&2 || cat "$tmp" >&2 || true
  rm -f "$tmp" 2>/dev/null || true
  exit 2
fi

new_url="$(jq -r '.url // empty' "$tmp" 2>/dev/null || true)"
new_id="$(jq -r '.id // .uid // empty' "$tmp" 2>/dev/null || true)"
rm -f "$tmp" 2>/dev/null || true

if [ -n "$new_url" ]; then
  echo "Vercel: redeploy triggered: https://${new_url} (id=${new_id:-unknown})" >&2
else
  echo "Vercel: redeploy triggered (id=${new_id:-unknown})." >&2
fi
