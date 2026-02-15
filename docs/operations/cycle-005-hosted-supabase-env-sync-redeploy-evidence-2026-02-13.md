# Cycle 005: Hosted Supabase Env Vars + Redeploy + Evidence (Ops Runbook)

Date: 2026-02-13

## Stage Diagnosis

Pre-PMF / early pilot. Treat hosted persistence evidence as a trust primitive: it proves the product works end-to-end (and that “answers are source-grounded” is backed by durable runtime state).

## Hosting Providers In This Repo

This repo ships a Next.js app in `projects/security-questionnaire-autopilot/` with hosted workflow APIs under `app/api/workflow/*`.

Supported hosting providers for the hosted runtime (based on committed automation/scripts):

- Vercel (primary / most natural for Next.js).
- Cloudflare Pages (supported via Pages API patching + optional deploy hook).

Provider selection is determined by whichever platform is actually serving your deployed `BASE_URL` for `/api/workflow/*`.

## Required Hosted Runtime Env Vars (Exact Names + Scope)

These must be set on the hosting provider that runs the Next.js workflow runtime:

- `NEXT_PUBLIC_SUPABASE_URL`
  - value: `https://<project-ref>.supabase.co`
  - scope:
    - Vercel: `Production` required; `Preview` recommended if you test previews.
    - Cloudflare Pages: `production` required; `preview` recommended.
  - sensitivity: non-secret (but still treat as config).
- `SUPABASE_SERVICE_ROLE_KEY`
  - value: Supabase service role key (server-side).
  - scope:
    - Vercel: `Production` required; `Preview` recommended. Must NOT be set for `Development` (Vercel “sensitive” restriction; enforced by script).
    - Cloudflare Pages: `production` required; `preview` recommended.
  - sensitivity: secret (must never be logged).

How the automation encodes this:

- Vercel API upsert:
  - `NEXT_PUBLIC_SUPABASE_URL` is written as `type=plain`
  - `SUPABASE_SERVICE_ROLE_KEY` is written as `type=sensitive`
  - default targets: `production,preview`
  - script: `projects/security-questionnaire-autopilot/scripts/vercel-upsert-project-env-vars.sh`
- Cloudflare Pages API upsert:
  - `NEXT_PUBLIC_SUPABASE_URL` is written as `type=plain_text`
  - `SUPABASE_SERVICE_ROLE_KEY` is written as `type=secret_text`
  - upserts both `deployment_configs.production.env_vars` and `deployment_configs.preview.env_vars`
  - script: `projects/security-questionnaire-autopilot/scripts/cloudflare-pages-upsert-project-env-vars.sh`

## Concrete Automatable Runbook (Preferred Order)

### 1) Identify The Correct Deployed `BASE_URL`

The correct `BASE_URL` is the deployed Next.js runtime that returns JSON from:

- `GET <BASE_URL>/api/workflow/env-health`

Operator workflow:

1. Collect 2-4 candidate origins from your hosting provider:
   - `https://<custom-domain>`
   - `https://<project>.vercel.app`
   - `https://<project>.pages.dev`
2. Probe candidates locally:

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  https://c1.example \
  https://c2.example \
  https://c3.example
```

3. Deterministically select the correct one:

```bash
BASE_URL="$(
  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
    https://c1.example \
    https://c2.example
)"
echo "$BASE_URL"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

If you’re early and env vars are not set yet, you can temporarily relax selection:

```bash
ALLOW_MISSING_SUPABASE_ENV=1 \
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  https://c1.example \
  https://c2.example
```

### 2) Set Hosted Runtime Env Vars + Trigger Redeploy

Two automation paths exist. Pick one.

#### Option A (Most Automatable): GitHub Actions Hosted Runtime Env Sync

Workflow:

- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml`

Inputs:

- `provider`: `vercel` or `cloudflare_pages`
- `base_url`: optional (if omitted, it tries repo variables / best-effort discovery)

Required GitHub secrets (source of truth for values):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Provider credentials needed by the workflow:

- Vercel:
  - secret: `VERCEL_TOKEN`
  - vars: `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
  - optional vars: `VERCEL_TEAM_ID`, `VERCEL_TEAM_SLUG`
  - optional secret: `VERCEL_DEPLOY_HOOK_URL` (fallback redeploy path)
- Cloudflare Pages:
  - secret: `CLOUDFLARE_API_TOKEN`
  - vars: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`
  - optional secret: `CF_PAGES_BUILD_HOOK_URL` (automatic rebuild trigger)

Execution:

1. Dispatch workflow in GitHub UI, or via `gh`:

```bash
gh workflow run cycle-005-hosted-runtime-env-sync.yml \
  -R nicepkg/auto-company \
  -f provider=vercel \
  -f base_url="https://<your-runtime-origin>"
```

2. Confirm success via:
   - Action logs
   - `curl -sS "<BASE_URL>/api/workflow/env-health" | jq .`

#### Option B (Local Operator Scripts): Provider API Upsert + Redeploy

Vercel (upsert + redeploy + poll):

```bash
export VERCEL_TOKEN="***"
export VERCEL_PROJECT_ID="***"  # or VERCEL_PROJECT="security-questionnaire-autopilot"
export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="***"

./scripts/devops/vercel-sync-supabase-env-and-redeploy.sh "https://<your-runtime-origin>"
```

Cloudflare Pages (upsert + optional deploy hook + poll):

```bash
export CLOUDFLARE_API_TOKEN="***"
export CLOUDFLARE_ACCOUNT_ID="***"
export CF_PAGES_PROJECT="***"
export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="***"

# optional: automate redeploy
export CF_PAGES_DEPLOY_HOOK_URL="https://***"

./projects/security-questionnaire-autopilot/scripts/cloudflare-pages-sync-supabase-env.sh "https://<your-runtime-origin>"
```

### 3) Verify Success (Hard Pass Criteria)

1. Env-health booleans are true:

```bash
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Must show:

- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

2. Supabase persistence health is ok (schema + seed):

```bash
curl -sS "$BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```

Must show:

- `.ok == true`
- `.tables.workflow_runs == true` and `.tables.workflow_events == true`
- `.schema.actual_schema_bundle_id == .schema.expected_schema_bundle_id`
- `.seed.present == true`

### 4) Re-Run Cycle 005 Hosted Persistence Evidence Flow

Two good ways to do this.

#### Evidence Path 1 (Local, Fast): Generate Evidence Artifacts + Append Sales Ledger

If SQL already applied via Supabase Dashboard SQL Editor:

```bash
export SKIP_SUPABASE_SQL_APPLY=1
./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh \
  "$BASE_URL" \
  "pilot-001-live-$(date +%Y%m%d-%H%M%S)"
```

Artifacts produced:

- `docs/qa/cycle-005-env-health-*.json`
- `docs/qa/cycle-005-supabase-health-*.json`
- `docs/devops/cycle-005-supabase-persistence-*.json`
- `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` appended with a new entry

#### Evidence Path 2 (Most Auditable): GitHub Actions Evidence Workflow (PR-based)

Workflow:

- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

Recommended:

- configure `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` repo variable (2-4 origins) once
- run with `skip_sql_apply=true` (apply SQL via Dashboard first)
- set `attempt_vercel_env_sync=true` only if you have Vercel creds in GitHub secrets/vars and want auto-fix

CLI dispatch helper:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo nicepkg/auto-company \
  --candidates "https://<c1> https://<c2>" \
  --skip-sql-apply true
```

## Evidence To Collect (What “Good” Looks Like)

- Provider proof:
  - Vercel: screenshot of Project env vars page showing both vars exist in Production (values redacted).
  - Cloudflare Pages: screenshot of project env vars for Production (values redacted).
- Runtime proof (committed artifacts):
  - `docs/qa/cycle-005-env-health-*.json`
  - `docs/qa/cycle-005-supabase-health-*.json`
  - `docs/devops/cycle-005-supabase-persistence-*.json`
- Workflow proof:
  - link to GitHub Actions run (Cycle 005 evidence workflow)
  - PR link with append-only evidence changes

## Current Status (This Workspace)

- GitHub CLI is authenticated locally.
- No hosted `BASE_URL` was confirmed from the candidate list last probed in `docs/qa-bach/cycle-005-base-url-probe-2026-02-13.txt` (Vercel reported `DEPLOYMENT_NOT_FOUND`; Pages DNS did not resolve).
- This environment does not currently have provider tokens or Supabase secrets in shell env (expected; should be stored in provider and/or GitHub secrets).

## Next Action

Provide the real deployed workflow runtime `BASE_URL` (must return JSON from `/api/workflow/env-health`) and confirm whether it’s Vercel or Cloudflare Pages; then run `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` for that provider and immediately rerun `.github/workflows/cycle-005-hosted-persistence-evidence.yml` (or the local `cycle-005-hosted-supabase-apply-and-run.sh`) to generate fresh evidence artifacts.

