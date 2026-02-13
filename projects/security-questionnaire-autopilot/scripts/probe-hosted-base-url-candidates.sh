#!/usr/bin/env bash
set -euo pipefail

# Probe candidate hosted app domains/URLs and print a quick diagnostic report.
#
# Accepts candidates via:
# - positional args
# - BASE_URL_CANDIDATES env var (comma/space separated)
#
# Probes: GET <BASE_URL>/api/workflow/env-health

usage() {
  cat >&2 <<'EOF'
Usage:
  probe-hosted-base-url-candidates.sh <candidate...>

Examples:
  ./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
    auto-company-git-main-foo.vercel.app \
    https://security-questionnaire-autopilot-hosted.pages.dev

  BASE_URL_CANDIDATES="auto-company.vercel.app, auto-company-hosted.vercel.app" \
    ./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  if [ -n "${BASE_URL_CANDIDATES:-}" ]; then
    mapfile -t _candidates < <(printf '%s' "$BASE_URL_CANDIDATES" | tr ',' ' ' | tr -s ' ' '\n' | sed '/^$/d')
    if [ "${#_candidates[@]}" -gt 0 ]; then
      set -- "${_candidates[@]}"
    fi
  fi
fi

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
  u="$(printf '%s' "$u" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  # Extract scheme://host while dropping any path/query fragments.
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\1#')"
  u="${u%/}"
  printf '%s' "$u"
}

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

printf '%s\n' "candidate_base_url  http  ok  supabase_url  service_role  note"

for raw in "$@"; do
  base="$(normalize_url "$raw")"
  endpoint="$base/api/workflow/env-health"

  out="$tmp_dir/body.json"
  hdr="$tmp_dir/headers.txt"

  code="$(curl -sS -m 12 -D "$hdr" -o "$out" -w "%{http_code}" "$endpoint" || echo "000")"

  ok="-"
  has_url="-"
  has_service="-"
  note=""

  if [ "$code" = "200" ] && jq -e '.' "$out" >/dev/null 2>&1; then
    ok="$(jq -r '.ok // empty' "$out" 2>/dev/null || true)"
    has_url="$(jq -r '.env.NEXT_PUBLIC_SUPABASE_URL // empty' "$out" 2>/dev/null || true)"
    has_service="$(jq -r '.env.SUPABASE_SERVICE_ROLE_KEY // empty' "$out" 2>/dev/null || true)"
    [ -n "$ok" ] || ok="-"
    [ -n "$has_url" ] || has_url="-"
    [ -n "$has_service" ] || has_service="-"
  else
    ctype="$(grep -i '^content-type:' "$hdr" 2>/dev/null | head -n 1 | sed -e 's/[[:space:]]*$//' || true)"
    sniff="$(head -c 120 "$out" 2>/dev/null | tr '\n' ' ' || true)"
    if [ -n "$ctype" ]; then
      note="$ctype"
    fi
    if [ -n "$sniff" ]; then
      note="${note:+$note }body_head='${sniff}'"
    fi
  fi

  printf '%s  %s  %s  %s  %s  %s\n' "$base" "$code" "$ok" "$has_url" "$has_service" "$note"
done
