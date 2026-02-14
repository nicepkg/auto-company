#!/usr/bin/env bash
set -euo pipefail

# Deterministically choose the correct deployed Next.js runtime BASE_URL (not marketing site)
# by probing the hosted workflow env-health endpoint.
#
# Usage:
#   ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh https://app.example.com https://example.com
#
# Output:
#   Prints the chosen BASE_URL to stdout (single line) and exits 0.

usage() {
  cat >&2 <<'EOF'
Usage:
  discover-hosted-base-url.sh <candidate_base_url...>

Notes:
  - Candidates should include scheme (https://...). Bare hostnames are treated as https://<hostname>.
  - If a candidate includes a path/query/fragment, it is ignored (only the origin is used).
  - In GitHub Actions, you may pass candidates via BASE_URL_CANDIDATES (comma/space separated)
    and call the script with no positional args.
  - The probe calls: GET <BASE_URL>/api/workflow/env-health
  - A valid hosted runtime must return JSON with:
      ok=true
      env.NEXT_PUBLIC_SUPABASE_URL=true
      env.SUPABASE_SERVICE_ROLE_KEY=true

Optional:
  - If ALLOW_MISSING_SUPABASE_ENV=1, the script only requires ok=true (useful for early BASE_URL
    validation before Supabase env vars are configured). Cycle 005 evidence runs should NOT set this.

Example:
  BASE_URL="$(
    ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
      https://app.example.com \
      https://www.example.com
  )"
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  if [ -n "${BASE_URL_CANDIDATES:-}" ]; then
    # Allow passing candidates via env (common in GitHub Actions).
    # Split on commas and whitespace.
    mapfile -t _candidates < <(printf '%s' "$BASE_URL_CANDIDATES" | tr ',' ' ' | tr -s ' ' '\n' | sed '/^$/d')
    if [ "${#_candidates[@]}" -gt 0 ]; then
      set -- "${_candidates[@]}"
    fi
  fi
fi

# If the caller passed a single arg containing commas/whitespace, split it too.
# This makes the script work the same way when invoked from workflow_dispatch inputs.
if [ "$#" -eq 1 ]; then
  if printf '%s' "$1" | grep -qE '[,[:space:]]'; then
    mapfile -t _candidates < <(printf '%s' "$1" | tr ',' ' ' | tr -s ' ' '\n' | sed '/^$/d')
    if [ "${#_candidates[@]}" -gt 0 ]; then
      set -- "${_candidates[@]}"
    fi
  fi
fi

if [ "$#" -lt 1 ]; then
  echo "Error: missing candidate base URLs. Provide positional args or set BASE_URL_CANDIDATES." >&2
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

normalize_url() {
  local u="$1"
  # Accept:
  # - full origins: https://app.example.com
  # - bare domains: app.example.com  (assume https://)
  # - accidental paths: https://app.example.com/some/path (strip to origin)
  #
  # Output is always: <scheme>://<host>[:port] with no trailing slash.
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  # Strip path/query/fragment (keep scheme://host[:port])
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\\1#')"
  # strip trailing slashes (defensive; should be none after origin strip)
  u="${u%/}"
  printf '%s' "$u"
}

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

fail_reasons=()

for raw in "$@"; do
  base="$(normalize_url "$raw")"
  # normalize_url guarantees scheme; keep this check as a defensive safety net.
  if [[ "$base" != http://* && "$base" != https://* ]]; then
    fail_reasons+=("$raw -> invalid base URL")
    continue
  fi

  out="$tmp_dir/body.json"
  hdr="$tmp_dir/headers.txt"
  endpoint="$base/api/workflow/env-health"

  echo "Probing: $endpoint" >&2
  code="$(curl -sS -m 12 -D "$hdr" -o "$out" -w "%{http_code}" "$endpoint" || echo "000")"

  if [ "$code" != "200" ]; then
    fail_reasons+=("$base -> env-health HTTP $code")
    continue
  fi

  # Reject non-JSON bodies (common when BASE_URL points at a marketing/static site).
  if ! jq -e '.' "$out" >/dev/null 2>&1; then
    sniff="$(head -c 120 "$out" 2>/dev/null | tr '\n' ' ' || true)"
    ctype="$(grep -i '^content-type:' "$hdr" 2>/dev/null | head -n 1 || true)"
    fail_reasons+=("$base -> env-health not JSON ($ctype) body_sniff='${sniff}'")
    continue
  fi

  if ! jq -e '.ok == true' "$out" >/dev/null 2>&1; then
    fail_reasons+=("$base -> env-health JSON but ok!=true")
    continue
  fi

  if [ "${ALLOW_MISSING_SUPABASE_ENV:-}" != "1" ] && [ "${ALLOW_MISSING_SUPABASE_ENV:-}" != "true" ]; then
    if ! jq -e '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true' "$out" >/dev/null 2>&1; then
      fail_reasons+=("$base -> hosted runtime reachable but missing Supabase env vars (set NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY on hosting provider, then redeploy)")
      continue
    fi
  fi

  # Success: print chosen base url.
  printf '%s\n' "$base"
  exit 0
done

echo "Error: no valid hosted Next.js runtime BASE_URL found." >&2
echo "Probe requirements: GET <BASE_URL>/api/workflow/env-health -> { ok:true, env:{ NEXT_PUBLIC_SUPABASE_URL:true, SUPABASE_SERVICE_ROLE_KEY:true } }" >&2
echo "" >&2
echo "Failures:" >&2
for r in "${fail_reasons[@]:-}"; do
  echo "  - $r" >&2
done
echo "" >&2
echo "Fixes (most common):" >&2
echo "1) BASE_URL is wrong (marketing/static domain, not the Next.js workflow API runtime)." >&2
echo "   BASE_URL must be the deployed app origin that serves /api/workflow/*." >&2
echo "   Tip: run the probe table to compare candidates:" >&2
echo "     ./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \"https://c1 https://c2\"" >&2
echo "" >&2
echo "2) Hosted runtime is reachable but missing Supabase env vars (env-health shows false booleans)." >&2
echo "   Set these on the hosting provider for the deployed runtime, then redeploy:" >&2
echo "     - NEXT_PUBLIC_SUPABASE_URL" >&2
echo "     - SUPABASE_SERVICE_ROLE_KEY" >&2
echo "" >&2
echo "   Where to set them:" >&2
echo "     - Vercel: Project -> Settings -> Environment Variables (Production at minimum), then redeploy" >&2
echo "     - Cloudflare Pages: Project -> Settings -> Environment variables (Production), then trigger a new deployment" >&2
echo "" >&2
echo "   Note: GitHub Actions secrets do NOT configure the hosted runtime unless your deployment pipeline maps them." >&2
echo "" >&2
echo "Docs:" >&2
echo "  - docs/qa/cycle-005-hosted-persistence-evidence-preflight.md" >&2
echo "  - docs/devops/base-url-discovery.md" >&2
echo "  - docs/devops/cycle-005-hosted-runtime-env-vars.md" >&2
echo "  - docs/operations/cycle-005-hosted-runtime-env-vars.md" >&2
exit 2
