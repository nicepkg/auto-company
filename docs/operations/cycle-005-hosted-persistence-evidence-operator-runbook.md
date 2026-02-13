# Cycle 005: Hosted Persistence Evidence (Operator Runbook)

## Stage

Pre-PMF / early pilot: prioritize trustworthy hosted evidence over signup volume.

## Top Operating Priorities

1. Use the correct deployed workflow runtime `BASE_URL` (not a marketing/static domain).
2. Confirm the hosted runtime is actually configured for persistence (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) and redeployed.
3. Produce an append-only evidence PR that updates `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.

## Weekly Goals (Measurable)

- 1 evidence PR opened by GitHub Actions that includes:
  - `docs/devops/cycle-005-supabase-persistence-*.json`
  - `docs/qa/cycle-005-*.json`
  - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` appended with a new `run_id=...` entry
- 0 “wrong domain” runs (guardrail: `/api/workflow/env-health` must be JSON with `ok=true`).

## Common Traps

- Pointing at a marketing site URL (HTML responses to `/api/*`).
- Provider deployment URL is stale (Vercel `DEPLOYMENT_NOT_FOUND` or old preview domain).
- Env vars are set in provider UI but deployment was not restarted/redeployed (env-health booleans stay `false`).

Fast fix guide:
- `docs/operations/cycle-005-hosted-runtime-env-vars.md`

## Collect 2-4 Candidate Domains (Do This First)

From the hosting provider for the workflow app (Vercel / Cloudflare Pages / etc), copy 2-4 origins:

- `https://<custom-domain>`
- `https://<project>.vercel.app`
- `https://<project>.pages.dev`

You can curate them in:

- `docs/devops/base-url-candidates.template.txt`

Then format to a single string:

```bash
./projects/security-questionnaire-autopilot/scripts/format-base-url-candidates.sh \
  docs/devops/base-url-candidates.template.txt
```

## Deterministically Select The Correct BASE_URL (Local Preflight)

Quick report across candidates:

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  <candidate-1> <candidate-2> <candidate-3>
```

Deterministic selection (must pass `/api/workflow/env-health` and show required env vars present):

```bash
BASE_URL="$(
  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
    <candidate-1> <candidate-2> <candidate-3>
)"
echo "$BASE_URL"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

## Make GitHub Actions Workflow-Dispatch “One Click”

Set a repo variable once (recommended):

- Variable: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (recommended)
- Value: the formatted candidates string (comma/space/newline separated)

Fallback variable names supported:

- `CYCLE_005_BASE_URL_CANDIDATES`
- `HOSTED_BASE_URL_CANDIDATES`
- `WORKFLOW_APP_BASE_URL_CANDIDATES`

If neither workflow input nor repo variables are set, the GitHub Actions workflow will attempt a best-effort candidate discovery via GitHub Deployments metadata (only works if your deploy pipeline publishes Deployment statuses with `environment_url` / `target_url`).

## Run The Evidence Workflow (GitHub Actions)

Workflow:

- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

Recommended inputs:

- `base_url`: leave empty if you set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (recommended)
- `skip_sql_apply`: `true` (preferred path is applying SQL via Supabase Dashboard SQL Editor first)

Pass criteria:

- The workflow selects `BASE_URL` via `/api/workflow/env-health`.
- The wrapper appends evidence into `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.
- The workflow opens a PR with the appended entry and evidence artifacts.

CLI path (recommended, does preflight + watch):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --skip-sql-apply true
```

Optional hardening (recommended if you want fail-fast fallback behavior):

- Add `--require-fallback-secrets` (enforces GitHub secrets `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` exist).
