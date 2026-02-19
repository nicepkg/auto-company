#!/usr/bin/env bash
set -euo pipefail

# QA wrapper around the Cycle 005 "no Supabase secrets" fallback path.
# Default output is role-owned under docs/qa-bach/.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_OUT_DIR="$ROOT/docs/qa-bach/cycle-005/postgres-service-apply-verify"

has_out_dir="0"
for a in "$@"; do
  if [ "$a" = "--out-dir" ]; then
    has_out_dir="1"
    break
  fi
done

args=("$@")
if [ "$has_out_dir" = "0" ]; then
  args=(--out-dir "$DEFAULT_OUT_DIR" "${args[@]}")
fi

exec "$ROOT/scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh" "${args[@]}"

