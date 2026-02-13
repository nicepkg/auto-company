#!/usr/bin/env bash
set -euo pipefail

# Deterministically select the correct deployed Next.js workflow runtime BASE_URL.
#
# Priority order for candidate sources:
# 1) positional args (if provided)
# 2) BASE_URL_CANDIDATES (comma/space separated)
# 3) HOSTED_WORKFLOW_BASE_URL_CANDIDATES (comma/space separated)
# 4) CYCLE_005_BASE_URL_CANDIDATES (comma/space separated; legacy name)
# 5) HOSTED_BASE_URL_CANDIDATES / WORKFLOW_APP_BASE_URL_CANDIDATES (legacy names)
# 6) Hosting provider APIs (best-effort; requires optional env vars; may be empty)
# 7) GitHub Deployments metadata (best-effort; may be empty)
#
# Output: prints the selected BASE_URL (single line) to stdout.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT/projects/security-questionnaire-autopilot"

DISCOVER="$PROJECT/scripts/discover-hosted-base-url.sh"
COLLECT_DEPLOYMENTS="$PROJECT/scripts/collect-base-url-candidates-from-github-deployments.sh"
COLLECT_HOSTING="$PROJECT/scripts/collect-base-url-candidates-from-hosting.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  select-hosted-base-url.sh [candidate_base_url...]

Environment inputs (optional):
  BASE_URL_CANDIDATES
  HOSTED_WORKFLOW_BASE_URL_CANDIDATES
  CYCLE_005_BASE_URL_CANDIDATES
  HOSTED_BASE_URL_CANDIDATES
  WORKFLOW_APP_BASE_URL_CANDIDATES

GitHub Deployments discovery (optional, best-effort):
  GITHUB_REPOSITORY, GITHUB_TOKEN

Notes:
  - Final selection is done by probing GET <BASE_URL>/api/workflow/env-health.
  - By default, the selected runtime must show:
      ok=true
      env.NEXT_PUBLIC_SUPABASE_URL=true
      env.SUPABASE_SERVICE_ROLE_KEY=true
    (Override via ALLOW_MISSING_SUPABASE_ENV=1 if you only want runtime identification.)
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

join_lines_to_space() {
  # stdin: newline-separated
  # stdout: space-separated
  tr '\n' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//'
}

have_env() {
  local name="$1"
  [ -n "${!name:-}" ]
}

candidates=""
source=""
if [ "$#" -gt 0 ]; then
  candidates="$*"
  source="positional_args"
fi

if [ -z "$candidates" ] && have_env "BASE_URL_CANDIDATES"; then
  candidates="${BASE_URL_CANDIDATES}"
  source="env:BASE_URL_CANDIDATES"
fi
if [ -z "$candidates" ] && have_env "HOSTED_WORKFLOW_BASE_URL_CANDIDATES"; then
  candidates="${HOSTED_WORKFLOW_BASE_URL_CANDIDATES}"
  source="env:HOSTED_WORKFLOW_BASE_URL_CANDIDATES"
fi
if [ -z "$candidates" ] && have_env "CYCLE_005_BASE_URL_CANDIDATES"; then
  candidates="${CYCLE_005_BASE_URL_CANDIDATES}"
  source="env:CYCLE_005_BASE_URL_CANDIDATES"
fi
if [ -z "$candidates" ] && have_env "HOSTED_BASE_URL_CANDIDATES"; then
  candidates="${HOSTED_BASE_URL_CANDIDATES}"
  source="env:HOSTED_BASE_URL_CANDIDATES"
fi
if [ -z "$candidates" ] && have_env "WORKFLOW_APP_BASE_URL_CANDIDATES"; then
  candidates="${WORKFLOW_APP_BASE_URL_CANDIDATES}"
  source="env:WORKFLOW_APP_BASE_URL_CANDIDATES"
fi

if [ -z "$candidates" ]; then
  # Hosting API discovery is optional; only attempts if the relevant env vars exist.
  # Vercel:
  # - VERCEL_TOKEN + (VERCEL_PROJECT_ID or VERCEL_PROJECT)
  # Cloudflare Pages:
  # - CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID + CF_PAGES_PROJECT
  if (have_env "VERCEL_TOKEN" && (have_env "VERCEL_PROJECT_ID" || have_env "VERCEL_PROJECT")) || \
     (have_env "CLOUDFLARE_API_TOKEN" && have_env "CLOUDFLARE_ACCOUNT_ID" && have_env "CF_PAGES_PROJECT"); then
    echo "No explicit BASE_URL candidates provided; attempting hosting API discovery..." >&2
    discovered="$("$COLLECT_HOSTING" | join_lines_to_space || true)"
    candidates="${discovered:-}"
    if [ -n "$candidates" ]; then
      source="hosting_apis"
    fi
  fi
fi

if [ -z "$candidates" ] && have_env "GITHUB_REPOSITORY" && have_env "GITHUB_TOKEN"; then
  echo "No explicit BASE_URL candidates provided; attempting GitHub Deployments discovery..." >&2
  discovered="$("$COLLECT_DEPLOYMENTS" | join_lines_to_space || true)"
  candidates="${discovered:-}"
  if [ -n "$candidates" ]; then
    source="github_deployments"
  fi
fi

if [ -z "$candidates" ]; then
  echo "Error: no BASE_URL candidates available." >&2
  echo "" >&2
  echo "Provide one of:" >&2
  echo "  - positional args: select-hosted-base-url.sh https://candidate1 https://candidate2" >&2
  echo "  - env var: BASE_URL_CANDIDATES='https://candidate1 https://candidate2'" >&2
  echo "  - repo variable (recommended for GHA): HOSTED_WORKFLOW_BASE_URL_CANDIDATES" >&2
  echo "" >&2
  echo "See: docs/devops/base-url-discovery.md" >&2
  exit 2
fi

echo "Using BASE_URL candidates source: ${source:-unknown}" >&2
export BASE_URL_CANDIDATES="$candidates"
exec "$DISCOVER"
