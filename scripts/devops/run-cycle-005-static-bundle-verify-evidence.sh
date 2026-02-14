#!/usr/bin/env bash
set -euo pipefail

# Cycle 005 fallback evidence that requires *no* Postgres runtime.
# Produces machine-checkable proof that the dashboard SQL bundle matches the
# repo's migration + seed inputs (prevents stale/hand-edited bundle drift).

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/devops/run-cycle-005-static-bundle-verify-evidence.sh [flags]

Flags:
  --bundle PATH   (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --out-dir DIR   (default: docs/devops-hightower/cycle-005/static-bundle-verify)

Outputs (under --out-dir):
  evidence-<ts>.json         machine-checkable result
  verify-stdout-<ts>.txt     command output (human-readable)
  latest.json                copy of evidence-<ts>.json
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

require_bin node
require_bin sha256sum

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BUNDLE="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
OUT_DIR="$ROOT/docs/devops-hightower/cycle-005/static-bundle-verify"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bundle) BUNDLE="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR"

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
out_json="$OUT_DIR/evidence-$ts.json"
out_txt="$OUT_DIR/verify-stdout-$ts.txt"

bundle_abs="$ROOT/$BUNDLE"
if [ "${BUNDLE#/}" != "$BUNDLE" ]; then
  bundle_abs="$BUNDLE"
fi

if [ ! -f "$bundle_abs" ]; then
  echo "Bundle not found: $BUNDLE" >&2
  exit 2
fi

proj="$ROOT/projects/security-questionnaire-autopilot"

set +e
stdout="$(
  cd "$proj" && \
    node scripts/verify-dashboard-sql-bundle.mjs --bundle "$bundle_abs" 2>&1
)"
rc="$?"
set -e

printf '%s\n' "$stdout" >"$out_txt"

bundle_sha="$(sha256sum "$bundle_abs" | awk '{print $1}')"
git_sha="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || true)"
schema_version_path="$proj/supabase/bundles/workflow-schema-version.json"
out_txt_rel="${out_txt#$ROOT/}"

RC="$rc" \
GIT_SHA="$git_sha" \
BUNDLE_REL="$BUNDLE" \
BUNDLE_ABS="$bundle_abs" \
BUNDLE_SHA="$bundle_sha" \
SCHEMA_VERSION_PATH="$schema_version_path" \
OUT_JSON="$out_json" \
OUT_TXT_REL="$out_txt_rel" \
node - <<'NODE'
const fs = require("node:fs");

const rc = Number(process.env.RC || "1");
const schemaRaw = fs.readFileSync(process.env.SCHEMA_VERSION_PATH, "utf8");
const schema = JSON.parse(schemaRaw);

const data = {
  checked_at_utc: new Date().toISOString(),
  ok: rc === 0,
  exit_code: rc,
  repo_git_sha: process.env.GIT_SHA ? String(process.env.GIT_SHA).trim() : null,
  inputs: {
    bundle: process.env.BUNDLE_REL,
    bundle_abs: process.env.BUNDLE_ABS
  },
  derived: {
    bundle_sha256: process.env.BUNDLE_SHA,
    workflow_schema_version: schema
  },
  verifier: {
    cmd: "node projects/security-questionnaire-autopilot/scripts/verify-dashboard-sql-bundle.mjs --bundle <abs>",
    stdout_path: process.env.OUT_TXT_REL
  }
};

fs.writeFileSync(process.env.OUT_JSON, JSON.stringify(data, null, 2) + "\n", "utf8");
NODE

cp "$out_json" "$OUT_DIR/latest.json"

echo "Wrote: $out_json" >&2
echo "Latest: $OUT_DIR/latest.json" >&2
