#!/usr/bin/env bash
set -euo pipefail

# Canonical hosted BASE_URL resolver for CI/workflows.
#
# Contract:
# - One (1) origin only. No candidate scanning / selection.
# - Source of truth in GitHub Actions should be repo variable: HOSTED_WORKFLOW_BASE_URL.
# - The origin must serve: GET <BASE_URL>/api/workflow/env-health
#
# This script normalizes (scheme + origin), rejects tunnel domains, and validates env-health.
#
# Usage:
#   resolve-hosted-workflow-base-url.sh [base_url]
#
# Inputs:
# - positional arg base_url (preferred for workflow_dispatch overrides)
# - else env HOSTED_WORKFLOW_BASE_URL
# - else env BASE_URL_CANDIDATES (accepted only if it contains exactly one token after normalization)
#
# Environment:
# - ALLOW_MISSING_SUPABASE_ENV=1 or true to only require env-health ok=true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROJECT="$ROOT/projects/security-questionnaire-autopilot"

FORMAT="$PROJECT/scripts/format-base-url-candidates.sh"
VALIDATE="$PROJECT/scripts/validate-base-url-candidates.sh"
PROBE="$PROJECT/scripts/discover-hosted-base-url.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  resolve-hosted-workflow-base-url.sh [base_url]

Notes:
  - Requires exactly one origin.
  - In GitHub Actions, prefer setting repo variable HOSTED_WORKFLOW_BASE_URL.
  - Legacy multi-candidate variables (e.g. HOSTED_WORKFLOW_BASE_URL_CANDIDATES) are intentionally unsupported here.

Examples:
  ./projects/security-questionnaire-autopilot/scripts/resolve-hosted-workflow-base-url.sh \
    https://auto-company-sq-autopilot.fly.dev

  HOSTED_WORKFLOW_BASE_URL="https://auto-company-sq-autopilot.fly.dev" \
    ./projects/security-questionnaire-autopilot/scripts/resolve-hosted-workflow-base-url.sh
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

raw="${1:-}"
source="positional_arg"

if [ -z "${raw:-}" ] && [ -n "${HOSTED_WORKFLOW_BASE_URL:-}" ]; then
  raw="${HOSTED_WORKFLOW_BASE_URL}"
  source="env:HOSTED_WORKFLOW_BASE_URL"
fi

if [ -z "${raw:-}" ] && [ -n "${BASE_URL_CANDIDATES:-}" ]; then
  raw="${BASE_URL_CANDIDATES}"
  source="env:BASE_URL_CANDIDATES"
fi

if [ -z "${raw:-}" ]; then
  echo "Missing BASE_URL." >&2
  echo "" >&2
  echo "Fix: set repo variable HOSTED_WORKFLOW_BASE_URL to the deployed Next.js workflow runtime origin." >&2
  echo "Expected: GET <BASE_URL>/api/workflow/env-health returns 200 JSON ok=true." >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

printf '%s\n' "${raw}" > "$tmp_dir/in.txt"
normalized="$("$FORMAT" "$tmp_dir/in.txt")"

count="$(printf '%s\n' "$normalized" | tr ' ' '\n' | sed '/^$/d' | wc -l | tr -d ' ')"
if [ "${count:-0}" != "1" ]; then
  echo "Invalid BASE_URL source (${source}): expected exactly 1 origin; got: ${normalized}" >&2
  echo "" >&2
  echo "Policy: CI/workflows accept one canonical hosted origin via HOSTED_WORKFLOW_BASE_URL." >&2
  echo "If you need to probe multiple candidates, run:" >&2
  echo "  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh <candidate1> <candidate2> ..." >&2
  exit 2
fi

# Guardrail: refuse tunnel origins.
"$VALIDATE" --validate-only "$normalized" >/dev/null

echo "Resolving BASE_URL (source=${source}) -> ${normalized}" >&2

# Validate env-health (and optionally require Supabase env vars).
resolved="$("$PROBE" "$normalized")"
printf '%s\n' "$resolved"

