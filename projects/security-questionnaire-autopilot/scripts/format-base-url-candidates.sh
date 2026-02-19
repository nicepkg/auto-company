#!/usr/bin/env bash
set -euo pipefail

# Format a simple "one URL per line" candidate list file into a single space-separated
# string suitable for:
# - GitHub Actions workflow_dispatch input: base_url
# - GitHub Actions repo variable: HOSTED_WORKFLOW_BASE_URL_CANDIDATES (recommended)
# - GitHub Actions repo variable: CYCLE_005_BASE_URL_CANDIDATES (legacy)
#
# Notes:
# - Blank lines and lines starting with '#' are ignored.
# - Commas/whitespace are treated as separators.
# - Trailing slashes are removed.
# - Order is preserved; duplicates are removed.

usage() {
  cat >&2 <<'EOF'
Usage:
  format-base-url-candidates.sh <file>

Example:
  ./projects/security-questionnaire-autopilot/scripts/format-base-url-candidates.sh \
    docs/devops/base-url-candidates.template.txt
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

FILE="${1:-}"
if [ -z "${FILE:-}" ]; then
  echo "Missing <file> argument" >&2
  usage
  exit 2
fi

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE" >&2
  exit 2
fi

declare -a out=()
declare -A seen=()

normalize() {
  local u="$1"
  # Accept:
  # - https://app.example.com
  # - app.example.com  (assume https://)
  # - https://app.example.com/some/path (strip to origin)
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\1#')"
  u="${u%/}"
  printf '%s' "$u"
}

while IFS= read -r line || [ -n "$line" ]; do
  # Strip leading/trailing whitespace
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
  esac

  # Split on commas and whitespace.
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    tok="$(normalize "$tok")"
    if [ -z "${seen[$tok]+x}" ]; then
      out+=("$tok")
      seen["$tok"]=1
    fi
  done < <(printf '%s\n' "$line" | tr ',' ' ' | tr -s ' ' '\n' | sed '/^$/d')
done < "$FILE"

if [ "${#out[@]}" -eq 0 ]; then
  echo "No candidates found in file: $FILE" >&2
  exit 2
fi

printf '%s' "${out[*]}"
