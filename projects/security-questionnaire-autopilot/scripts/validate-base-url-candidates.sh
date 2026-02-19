#!/usr/bin/env bash
set -euo pipefail

# Validate/filter BASE_URL candidates to avoid persisting ephemeral tunnel origins into
# repo variables (which can poison CI).
#
# Input formats:
# - args: space/comma separated URLs/hosts
# - --file <path>: read from file (supports comments and blank lines)
#
# Output:
# - prints a normalized, de-duplicated, space-separated candidate list to stdout
# - exits non-zero if all candidates are filtered out or if --validate-only is used and any
#   disallowed candidates are present

usage() {
  cat >&2 <<'EOF'
Usage:
  validate-base-url-candidates.sh [--validate-only] [--file <path>] [candidates...]

Examples:
  # Validate a single BASE_URL (fails if it looks like a tunnel origin)
  ./projects/security-questionnaire-autopilot/scripts/validate-base-url-candidates.sh --validate-only \
    https://workflow.example.com

  # Filter a mixed list (drops tunnels, keeps stable origins)
  ./projects/security-questionnaire-autopilot/scripts/validate-base-url-candidates.sh \
    "https://foo.trycloudflare.com https://workflow.example.com"

  # Validate/filter from a file
  ./projects/security-questionnaire-autopilot/scripts/validate-base-url-candidates.sh --file docs/devops/base-url-candidates.txt

Environment:
  DISALLOWED_BASE_URL_HOST_REGEX
    Regex matched against candidate hostnames (no scheme, no path, no port).
    Default blocks common tunnel domains.
EOF
}

VALIDATE_ONLY=0
FILE=""

while [ "${1:-}" != "" ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --validate-only)
      VALIDATE_ONLY=1
      shift
      ;;
    --file)
      FILE="${2:-}"
      if [ -z "${FILE:-}" ]; then
        echo "Missing value for --file" >&2
        exit 2
      fi
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

# Remaining CLI args (if any) are candidate tokens or a single blob.
RAW_CANDIDATES="$*"

# Match against candidate hostnames (no scheme, no path, no port).
# Keep this conservative: block common tunnel domains that should never be persisted into CI config.
DISALLOWED_BASE_URL_HOST_REGEX="${DISALLOWED_BASE_URL_HOST_REGEX:-(^|\\.)trycloudflare\\.com$}"
DISALLOWED_BASE_URL_HOST_REGEX="${DISALLOWED_BASE_URL_HOST_REGEX}|${DISALLOWED_BASE_URL_HOST_REGEX_EXTRA:-(^|\\.)loca\\.lt$|(^|\\.)localtunnel\\.me$|(^|\\.)ngrok(-free\\.app|\\.io|\\.app)?$}"

normalize_origin() {
  local u="$1"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="https://$u"
  fi
  # Strip to origin and remove trailing slash.
  u="$(printf '%s' "$u" | sed -E 's#^(https?://[^/]+).*$#\1#')"
  u="${u%/}"
  printf '%s' "$u"
}

origin_host() {
  local u="$1"
  # u is expected to be an origin: https?://host[:port]
  u="${u#http://}"
  u="${u#https://}"
  u="${u%%/*}"
  # Strip port if present.
  u="${u%%:*}"
  printf '%s' "$u"
}

emit_tokens() {
  if [ -n "${FILE:-}" ]; then
    if [ ! -f "$FILE" ]; then
      echo "File not found: $FILE" >&2
      exit 2
    fi
    while IFS= read -r line || [ -n "$line" ]; do
      line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [ -z "$line" ] && continue
      case "$line" in
        \#*) continue ;;
      esac
      printf '%s\n' "$line"
    done < "$FILE"
  else
    # Keep as-is and split later.
    printf '%s\n' "${RAW_CANDIDATES:-}"
  fi
}

declare -a out=()
declare -A seen=()
declare -a removed=()

while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    tok="$(normalize_origin "$tok")"
    host="$(origin_host "$tok")"
    # Use grep -E for portability (works on GitHub Actions runners by default).
    if printf '%s' "$host" | grep -Eq "$DISALLOWED_BASE_URL_HOST_REGEX"; then
      removed+=("$tok")
      continue
    fi
    if [ -z "${seen[$tok]+x}" ]; then
      out+=("$tok")
      seen["$tok"]=1
    fi
  done < <(printf '%s\n' "$line" | tr ',' ' ' | tr -s ' ' '\n' | sed '/^$/d')
done < <(emit_tokens)

if [ "${#removed[@]}" -gt 0 ] && [ "$VALIDATE_ONLY" -eq 1 ]; then
  echo "Disallowed BASE_URL candidate(s) detected (likely tunnel origins). Refusing to proceed." >&2
  echo "DISALLOWED_BASE_URL_HOST_REGEX=$DISALLOWED_BASE_URL_HOST_REGEX" >&2
  printf '%s\n' "${removed[@]}" | sed 's/^/- /' >&2
  exit 2
fi

if [ "${#out[@]}" -eq 0 ]; then
  echo "No allowed BASE_URL candidates remain after validation/filtering." >&2
  if [ "${#removed[@]}" -gt 0 ]; then
    echo "Filtered disallowed candidate(s):" >&2
    printf '%s\n' "${removed[@]}" | sed 's/^/- /' >&2
  fi
  exit 2
fi

if [ "${#removed[@]}" -gt 0 ] && [ "$VALIDATE_ONLY" -eq 0 ]; then
  echo "Warning: filtered ${#removed[@]} disallowed BASE_URL candidate(s) (likely tunnel origins)." >&2
fi

printf '%s' "${out[*]}"
