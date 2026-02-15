#!/usr/bin/env bash
set -euo pipefail

# Operator wrapper: dispatch cycle-005-hosted-runtime-env-sync workflow via gh.
#
# Goal: reduce manual clicking when the hosted runtime is missing:
#   - NEXT_PUBLIC_SUPABASE_URL
#   - SUPABASE_SERVICE_ROLE_KEY
#
# This wrapper intentionally does NOT accept raw secret values; the workflow
# sources Supabase values from GitHub Actions secrets and syncs them into the
# hosting provider env (Vercel/Cloudflare Pages).

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-hosted-runtime-env-sync.sh [flags]

Flags:
  --repo OWNER/REPO                (default: inferred via gh from git remote)
  --provider vercel|cloudflare_pages (default: vercel)
  --base-url URL                   Optional BASE_URL to validate after redeploy (expects /api/workflow/env-health)
  --candidates "u1 u2 ..."         Optional candidate origins (use with --set-variable to persist)
  --candidates-file PATH           Read candidates from file (one per line; comments allowed)
  --set-variable                   Write candidates into repo variable HOSTED_WORKFLOW_BASE_URL_CANDIDATES
  --poll-timeout-seconds N         (default: 240)

Notes:
  - Requires gh auth AND repo permission >= WRITE to dispatch workflows / set variables.
  - For vercel: if --base-url is empty but candidates are present (repo var or input),
    the workflow will attempt best-effort BASE_URL discovery.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing dependency: $name" >&2
    exit 2
  fi
}

require_bin "gh"

REPO=""
PROVIDER="vercel"
BASE_URL=""
CANDIDATES=""
CANDIDATES_FILE=""
SET_VARIABLE="0"
POLL_TIMEOUT_SECONDS="240"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    --candidates) CANDIDATES="${2:-}"; shift 2 ;;
    --candidates-file) CANDIDATES_FILE="${2:-}"; shift 2 ;;
    --set-variable) SET_VARIABLE="1"; shift 1 ;;
    --poll-timeout-seconds) POLL_TIMEOUT_SECONDS="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

gh auth status -h github.com >/dev/null

if [ -z "${REPO:-}" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPO:-}" ]; then
  echo "Could not infer --repo. Re-run with: --repo OWNER/REPO" >&2
  exit 2
fi

perm="$(gh repo view "$REPO" --json viewerPermission -q .viewerPermission 2>/dev/null || echo "")"
case "$perm" in
  ADMIN|MAINTAIN|WRITE) ;;
  *)
    echo "Insufficient GitHub repo permission to dispatch workflows or set variables." >&2
    echo "repo=$REPO viewerPermission=${perm:-unknown}" >&2
    echo "Fix: run as a maintainer (>= WRITE) or ask an admin to run the workflow in the GitHub UI." >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FORMAT="$ROOT/projects/security-questionnaire-autopilot/scripts/format-base-url-candidates.sh"

if [ -n "${CANDIDATES_FILE:-}" ]; then
  if [ ! -f "$CANDIDATES_FILE" ]; then
    echo "Candidates file not found: $CANDIDATES_FILE" >&2
    exit 2
  fi
  CANDIDATES="$("$FORMAT" "$CANDIDATES_FILE")"
fi

if [ "${SET_VARIABLE}" = "1" ]; then
  if [ -z "${CANDIDATES:-}" ]; then
    echo "--set-variable requires --candidates or --candidates-file" >&2
    exit 2
  fi
  gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "$CANDIDATES" >/dev/null
fi

wf="cycle-005-hosted-runtime-env-sync.yml"

args=(workflow run "$wf" -R "$REPO" -f "provider=$PROVIDER" -f "base_url=$BASE_URL" -f "poll_timeout_seconds=$POLL_TIMEOUT_SECONDS")
echo "Dispatching: gh ${args[*]}" >&2
gh "${args[@]}" >/dev/null

echo "Dispatched workflow. Track it with:" >&2
echo "  gh run list -R \"$REPO\" --workflow \"$wf\" -L 5" >&2
