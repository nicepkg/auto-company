#!/usr/bin/env bash
set -euo pipefail

# Cycle 018 objective helper:
# Fully-scripted, evidence-producing GitHub Actions ops for Supabase provision+apply+verify.
#
# Requires:
# - gh (GitHub CLI) authenticated via GH_TOKEN (recommended) or prior `gh auth login`
# - jq
#
# What it does:
# 1) Verify required repo secrets exist (SUPABASE_ACCESS_TOKEN, SUPABASE_ORG_SLUG, SUPABASE_DB_PASSWORD)
# 2) Optionally set missing secrets from env (or prompt)
# 3) Dispatch `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`
# 4) Wait for completion and download run artifacts (including supabase-verify.json)
# 5) Write evidence into docs/operations-pg/...

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

WORKFLOW_FILE_DEFAULT=".github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml"
SQL_BUNDLE_DEFAULT="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
SUPABASE_PROJECT_NAME_DEFAULT="security-questionnaire-autopilot-cycle-005"
REUSE_EXISTING_DEFAULT="true"

OUT_BASE_DEFAULT="$ROOT/docs/operations-pg/cycle-018-supabase-ci"

REQUIRED_SECRETS=("SUPABASE_ACCESS_TOKEN" "SUPABASE_ORG_SLUG" "SUPABASE_DB_PASSWORD")

usage() {
  cat <<'USAGE' >&2
Usage:
  ./scripts/ops/cycle-018-supabase-ci.sh all [options]
  ./scripts/ops/cycle-018-supabase-ci.sh check-secrets [options]
  ./scripts/ops/cycle-018-supabase-ci.sh set-secrets [options]
  ./scripts/ops/cycle-018-supabase-ci.sh dispatch [options]
  ./scripts/ops/cycle-018-supabase-ci.sh download --run-id <id> [options]

Options:
  --repo <owner/name>                 Override repo (default: inferred from `gh repo view`)
  --ref <branch>                      Dispatch ref (default: repo default branch)
  --workflow <path-or-name>           Workflow file/name (default: .github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml)
  --supabase-project-name <name>      Workflow input (default: security-questionnaire-autopilot-cycle-005)
  --reuse-existing <true|false>       Workflow input (default: true)
  --sql-bundle <workspace-path>        Workflow input (default: projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql)
  --out-base <dir>                    Evidence output base (default: docs/operations-pg/cycle-018-supabase-ci)
  --prompt                            Prompt for missing secret values (SUPABASE_*), without echo
  --no-watch                          Do not wait for run completion (dispatch only)
  --timeout-seconds <n>               Max seconds to wait for new run detection (default: 180)

Env inputs (used by set-secrets):
  SUPABASE_ACCESS_TOKEN, SUPABASE_ORG_SLUG, SUPABASE_DB_PASSWORD

Notes:
  - This script never prints secret values; it only sets them.
  - Evidence (JSON + downloaded artifacts) lands in docs/operations-pg/cycle-018-supabase-ci/run-<ts>/...
USAGE
}

die() { echo "error: $*" >&2; exit 2; }

require_bin() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "missing dependency: $name"
}

need_auth() {
  if ! gh auth status >/dev/null 2>&1; then
    cat >&2 <<'EOF'
GitHub CLI not authenticated.
Fix:
  export GH_TOKEN="<a GitHub PAT with repo + workflow scope>"
  gh auth status
EOF
    exit 2
  fi
}

json_write() {
  local out="$1"
  shift
  jq -n "$@" >"$out"
}

ts_utc() { date -u +"%Y%m%dT%H%M%SZ"; }

prompt_secret() {
  local var="$1"
  local label="$2"
  if [ -n "${!var:-}" ]; then
    return 0
  fi
  read -r -s -p "$label: " "$var" </dev/tty
  echo "" >/dev/tty
  if [ -z "${!var:-}" ]; then
    die "missing required value for $var"
  fi
  export "$var"
}

repo_name_with_owner() {
  gh repo view --json nameWithOwner -q .nameWithOwner
}

repo_default_branch() {
  gh repo view --json defaultBranchRef -q .defaultBranchRef.name
}

gh_login() {
  gh api user -q .login 2>/dev/null || true
}

secrets_list_json() {
  local repo="$1"
  # `gh secret list --json` is the least brittle; fall back to text parsing if needed.
  if gh secret list -R "$repo" --json name,updatedAt >/dev/null 2>&1; then
    gh secret list -R "$repo" --json name,updatedAt
  else
    # Older gh versions: output "NAME\tUPDATED"
    gh secret list -R "$repo" | awk 'NR>1 {print $1}' | jq -Rsc 'split("\n")|map(select(length>0))|map({name: ., updatedAt: null})'
  fi
}

missing_required_secrets_json() {
  local secrets_json="$1" # json file with [{name,...}]
  jq -r --argjson req "$(printf '%s\n' "${REQUIRED_SECRETS[@]}" | jq -Rsc 'split("\n")|map(select(length>0))')" '
    ( [ .[]?.name ] | unique ) as $have
    | [ $req[] | select( ($have | index(.)) | not ) ]
  ' "$secrets_json"
}

set_secret() {
  local repo="$1"
  local name="$2"
  local envvar="$3"
  local prompt="${4:-0}"

  if [ -z "${!envvar:-}" ]; then
    if [ "$prompt" = "1" ]; then
      if [ "$envvar" = "SUPABASE_ORG_SLUG" ]; then
        read -r -p "SUPABASE_ORG_SLUG: " "$envvar" </dev/tty
        export "$envvar"
      else
        prompt_secret "$envvar" "$envvar"
      fi
    else
      die "missing env var: $envvar (needed to set GitHub secret $name). Use --prompt or export it."
    fi
  fi

  # Avoid leaking the secret via process args: feed via stdin.
  printf '%s' "${!envvar}" | gh secret set "$name" -R "$repo" --body -
}

dispatch_workflow() {
  local repo="$1"
  local workflow="$2"
  local ref="$3"
  local supabase_project_name="$4"
  local reuse_existing="$5"
  local sql_bundle="$6"
  local out_dir="$7"
  local detect_timeout_s="$8"

  local start_epoch run_id
  start_epoch="$(date -u +%s)"

  json_write "$out_dir/dispatch.request.json" \
    --arg repo "$repo" \
    --arg workflow "$workflow" \
    --arg ref "$ref" \
    --arg supabase_project_name "$supabase_project_name" \
    --arg reuse_existing "$reuse_existing" \
    --arg sql_bundle "$sql_bundle" \
    --arg ts "$(ts_utc)" \
    '{
      repo: $repo,
      workflow: $workflow,
      ref: $ref,
      inputs: {
        supabase_project_name: $supabase_project_name,
        reuse_existing: $reuse_existing,
        sql_bundle: $sql_bundle
      },
      dispatched_at_utc: $ts
    }'

  gh workflow run "$workflow" -R "$repo" --ref "$ref" \
    -f "supabase_project_name=$supabase_project_name" \
    -f "reuse_existing=$reuse_existing" \
    -f "sql_bundle=$sql_bundle" >/dev/null

  # Find the newly created run id (databaseId) by polling run list.
  local deadline now
  deadline="$(( start_epoch + detect_timeout_s ))"
  while :; do
    now="$(date -u +%s)"
    if [ "$now" -ge "$deadline" ]; then
      die "timed out detecting the workflow run (waited ${detect_timeout_s}s). Use: gh run list -R \"$repo\" --workflow \"$workflow\""
    fi
    run_id="$(
      gh run list -R "$repo" --workflow "$workflow" --json databaseId,createdAt,event,headBranch,status,conclusion,url \
        -q ".[] | select(.event==\"workflow_dispatch\") | select(.headBranch==\"$ref\") | select((.createdAt|fromdateiso8601) >= $start_epoch) | .databaseId" \
        | head -n 1
    )"
    if [ -n "${run_id:-}" ] && [ "$run_id" != "null" ]; then
      break
    fi
    sleep 5
  done

  printf '%s\n' "$run_id" >"$out_dir/run.id.txt"
  gh run view "$run_id" -R "$repo" --json databaseId,url,status,conclusion,createdAt,updatedAt,headBranch,event,name,workflowName \
    >"$out_dir/run.view.json"

  echo "$run_id"
}

download_artifacts() {
  local repo="$1"
  local run_id="$2"
  local out_dir="$3"

  mkdir -p "$out_dir/artifacts"

  gh api "repos/${repo}/actions/runs/${run_id}" >"$out_dir/run.api.json"
  gh api "repos/${repo}/actions/runs/${run_id}/artifacts" >"$out_dir/run.artifacts.json" || true

  # Download all artifacts (there should be 1 artifact bundle for this workflow).
  gh run download "$run_id" -R "$repo" -D "$out_dir/artifacts" >/dev/null || true

  (cd "$out_dir" && find artifacts -type f -maxdepth 4 -print | sort) >"$out_dir/artifacts.files.txt" || true

  # Convenience: copy the verify JSON to a stable top-level path if present.
  local verify
  verify="$(find "$out_dir/artifacts" -type f -name 'supabase-verify.json' | head -n 1 || true)"
  if [ -n "$verify" ]; then
    cp -f "$verify" "$out_dir/supabase-verify.json"
  fi
}

cmd="${1:-}"
shift || true

repo=""
ref=""
workflow="$WORKFLOW_FILE_DEFAULT"
supabase_project_name="$SUPABASE_PROJECT_NAME_DEFAULT"
reuse_existing="$REUSE_EXISTING_DEFAULT"
sql_bundle="$SQL_BUNDLE_DEFAULT"
out_base="$OUT_BASE_DEFAULT"
prompt="0"
watch="1"
detect_timeout_s="180"
run_id=""

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --repo) repo="${2:-}"; shift 2 ;;
    --ref) ref="${2:-}"; shift 2 ;;
    --workflow) workflow="${2:-}"; shift 2 ;;
    --supabase-project-name) supabase_project_name="${2:-}"; shift 2 ;;
    --reuse-existing) reuse_existing="${2:-}"; shift 2 ;;
    --sql-bundle) sql_bundle="${2:-}"; shift 2 ;;
    --out-base) out_base="${2:-}"; shift 2 ;;
    --prompt) prompt="1"; shift 1 ;;
    --no-watch) watch="0"; shift 1 ;;
    --timeout-seconds) detect_timeout_s="${2:-}"; shift 2 ;;
    --run-id) run_id="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown arg: ${1:-} (use --help)" ;;
  esac
done

require_bin gh
require_bin jq
need_auth

if [ -z "$repo" ]; then
  repo="$(repo_name_with_owner)"
fi
if [ -z "$ref" ]; then
  ref="$(repo_default_branch)"
fi

workflow_sel="$workflow"
if [[ "$workflow_sel" == */* ]]; then
  # gh typically accepts a workflow file name (not necessarily a full repo-relative path).
  workflow_sel="${workflow_sel##*/}"
fi

run_ts="$(ts_utc)"
out_dir="$out_base/run-$run_ts"
mkdir -p "$out_dir"

json_write "$out_dir/context.json" \
  --arg repo "$repo" \
  --arg ref "$ref" \
  --arg workflow "$workflow" \
  --arg workflow_selector "$workflow_sel" \
  --arg out_dir "$out_dir" \
  --arg operator "$(gh_login)" \
  --arg ts "$run_ts" \
  '{
    repo: $repo,
    ref: $ref,
    workflow: $workflow,
    workflow_selector: $workflow_selector,
    out_dir: $out_dir,
    operator: ($operator // ""),
    started_at_utc: $ts
  }'

case "$cmd" in
  check-secrets)
    secrets_list_json "$repo" >"$out_dir/secrets.before.json"
    missing_required_secrets_json "$out_dir/secrets.before.json" >"$out_dir/secrets.missing.before.json"
    echo "evidence_dir=$out_dir"
    echo -n "missing_secrets="
    jq -c '.' "$out_dir/secrets.missing.before.json"
    cat "$out_dir/secrets.missing.before.json" | jq -e 'length == 0' >/dev/null || exit 3
    ;;

  set-secrets)
    secrets_list_json "$repo" >"$out_dir/secrets.before.json"
    missing_required_secrets_json "$out_dir/secrets.before.json" >"$out_dir/secrets.missing.before.json"

    # Set only missing.
    to_set="$(jq -r '.[]' "$out_dir/secrets.missing.before.json" || true)"
    if [ -z "${to_set:-}" ]; then
      json_write "$out_dir/secrets.set.json" --arg ts "$(ts_utc)" '{set: [], set_at_utc: $ts}'
      exit 0
    fi

    set_list=()
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      case "$name" in
        SUPABASE_ACCESS_TOKEN) set_secret "$repo" "$name" "SUPABASE_ACCESS_TOKEN" "$prompt" ;;
        SUPABASE_ORG_SLUG) set_secret "$repo" "$name" "SUPABASE_ORG_SLUG" "$prompt" ;;
        SUPABASE_DB_PASSWORD) set_secret "$repo" "$name" "SUPABASE_DB_PASSWORD" "$prompt" ;;
        *) die "unexpected secret name in required list: $name" ;;
      esac
      set_list+=("$name")
    done <<<"$to_set"

    printf '%s\n' "${set_list[@]}" | jq -Rsc 'split("\n")|map(select(length>0))' >"$out_dir/secrets.set.names.json"
    json_write "$out_dir/secrets.set.json" \
      --arg ts "$(ts_utc)" \
      --slurpfile names "$out_dir/secrets.set.names.json" \
      '{set: ($names[0] // []), set_at_utc: $ts}'

    secrets_list_json "$repo" >"$out_dir/secrets.after.json"
    missing_required_secrets_json "$out_dir/secrets.after.json" >"$out_dir/secrets.missing.after.json"
    cat "$out_dir/secrets.missing.after.json" | jq -e 'length == 0' >/dev/null
    echo "evidence_dir=$out_dir"
    echo -n "secrets_set="
    jq -c '.set' "$out_dir/secrets.set.json"
    ;;

  dispatch)
    run_id="$(dispatch_workflow "$repo" "$workflow_sel" "$ref" "$supabase_project_name" "$reuse_existing" "$sql_bundle" "$out_dir" "$detect_timeout_s")"
    if [ "$watch" = "1" ]; then
      gh run watch "$run_id" -R "$repo" --exit-status || true
    fi
    echo "evidence_dir=$out_dir"
    echo "run_id=$run_id"
    echo -n "run_url="
    jq -r '.url // empty' "$out_dir/run.view.json" 2>/dev/null || true
    ;;

  download)
    [ -n "${run_id:-}" ] || die "--run-id is required for download"
    download_artifacts "$repo" "$run_id" "$out_dir"
    echo "evidence_dir=$out_dir"
    if [ -f "$out_dir/supabase-verify.json" ]; then
      echo "supabase_verify_json=$out_dir/supabase-verify.json"
    fi
    ;;

  all)
    # 1) Check secrets
    secrets_list_json "$repo" >"$out_dir/secrets.before.json"
    missing_required_secrets_json "$out_dir/secrets.before.json" >"$out_dir/secrets.missing.before.json"

    # 2) Set missing secrets (if any)
    if ! cat "$out_dir/secrets.missing.before.json" | jq -e 'length == 0' >/dev/null; then
      set_list=()
      while IFS= read -r name; do
        [ -n "$name" ] || continue
        case "$name" in
          SUPABASE_ACCESS_TOKEN) set_secret "$repo" "$name" "SUPABASE_ACCESS_TOKEN" "$prompt" ;;
          SUPABASE_ORG_SLUG) set_secret "$repo" "$name" "SUPABASE_ORG_SLUG" "$prompt" ;;
          SUPABASE_DB_PASSWORD) set_secret "$repo" "$name" "SUPABASE_DB_PASSWORD" "$prompt" ;;
          *) die "unexpected secret name in required list: $name" ;;
        esac
        set_list+=("$name")
      done < <(jq -r '.[]' "$out_dir/secrets.missing.before.json")

      printf '%s\n' "${set_list[@]}" | jq -Rsc 'split("\n")|map(select(length>0))' >"$out_dir/secrets.set.names.json"
      json_write "$out_dir/secrets.set.json" \
        --arg ts "$(ts_utc)" \
        --slurpfile names "$out_dir/secrets.set.names.json" \
        '{set: ($names[0] // []), set_at_utc: $ts}'

      secrets_list_json "$repo" >"$out_dir/secrets.after.json"
      missing_required_secrets_json "$out_dir/secrets.after.json" >"$out_dir/secrets.missing.after.json"
      cat "$out_dir/secrets.missing.after.json" | jq -e 'length == 0' >/dev/null || die "required secrets still missing after set attempt"
    else
      json_write "$out_dir/secrets.set.json" --arg ts "$(ts_utc)" '{set: [], set_at_utc: $ts}'
    fi

    # 3) Dispatch
    run_id="$(dispatch_workflow "$repo" "$workflow_sel" "$ref" "$supabase_project_name" "$reuse_existing" "$sql_bundle" "$out_dir" "$detect_timeout_s")"

    # 4) Wait
    if [ "$watch" = "1" ]; then
      gh run watch "$run_id" -R "$repo" --exit-status || true
    fi

    # 5) Download artifacts
    download_artifacts "$repo" "$run_id" "$out_dir"

    echo "evidence_dir=$out_dir"
    echo "run_id=$run_id"
    if [ -f "$out_dir/supabase-verify.json" ]; then
      echo "supabase_verify_json=$out_dir/supabase-verify.json"
    fi
    ;;

  *)
    usage
    exit 2
    ;;
esac
