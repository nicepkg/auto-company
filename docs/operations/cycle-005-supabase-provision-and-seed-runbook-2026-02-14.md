# Cycle 005: Provision Supabase + Apply Schema/Seed (Ops, Deterministic)

Date: 2026-02-14
Owner: operations-pg

## Stage Diagnosis

Pre-PMF. The goal is not “perfect infra”, it is a single dependable hosted runtime + single dependable Supabase project so Cycle 005 preflight can pass on demand.

Pass criterion for this task:

`GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns HTTP `200` with JSON `{ ok: true, ... }`.

## Top Operating Priorities (Next 1-2 days)

1. Create or identify the one Supabase project that the hosted runtime will use.
2. Apply the shipped SQL bundle (migration + seed) to that Supabase database.
3. Ensure hosted runtime env vars point at that project, then redeploy and re-check `supabase-health`.

## Weekly Goals (Measurable)

- 1 stable Supabase project exists and is documented by `project_ref`.
- SQL bundle applied once (idempotent) and `supabase-health` is green with `requireSeed=1&requirePilotDeals=1`.
- A Cycle 005 preflight run succeeds without manual patching.

## Common Traps (Avoid)

- Wrong Supabase project: tables exist, but `workflow_app_meta.schema_bundle_id` mismatches expected bundle id.
- Seed missing: `workflow_runs` exists, but `pilot-001-live-2026-02-13` is not present.
- “Env vars set” but no redeploy: `env-health` keeps reporting missing vars.
- Secrets leakage: pasting DB URLs / keys into shell history or committing generated files.

## Required Secrets / Vars (Names Only)

Supabase provisioning (only if automating project creation):
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_PROJECT_NAME`
- `SUPABASE_DB_PASSWORD`
- `SUPABASE_REGION` (optional)
- `SUPABASE_PROMPT_FOR_MISSING=1` (optional; local interactive mode, avoids pre-setting env vars)

Applying schema + seed (choose one path):
- `SUPABASE_DB_URL` (only for direct DB apply via Node/pg or psql)
- or: `SUPABASE_PROJECT_REF` + `SUPABASE_DB_PASSWORD` (deterministic `SUPABASE_DB_URL` build, avoids copy/paste)

Hosted runtime (must be set on the deployed Next.js environment that serves `/api/workflow/*`):
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (can be Supabase legacy `service_role` key or the newer secret key; store as a server-only secret)

## Execution Runbook

### Step 0: Confirm Your Hosted Runtime `BASE_URL`

Your `BASE_URL` must return JSON from:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq .
```

If you need discovery, use:
- `projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh`
- `projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh`

### Step 1: Provision the Supabase Project

Pick one.

Option A (most reliable, manual, no tokens on this machine):
1. Supabase Dashboard: create a new project (record `project_ref`).
2. Set a DB password (store in your secret manager).

Option B (automated, once you have a Supabase access token):

```bash
export SUPABASE_PROMPT_FOR_MISSING=1
./projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh
```

This writes a sanitized summary JSON into `docs/operations/` and prints safe, machine-parsable lines like:
- `project_ref=<project_ref>`
- `project_url=https://<project_ref>.supabase.co`
- `db_host=db.<project_ref>.supabase.co`

Safety note: the script does not print secrets (token/password/api keys).

Option C (automated + repeatable, no local secrets needed): GitHub Actions
- Workflow (provision + apply + verify): `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`
- Required GitHub secrets (names): `SUPABASE_ACCESS_TOKEN`, `SUPABASE_ORG_SLUG`, `SUPABASE_DB_PASSWORD`
- This workflow provisions (or reuses) the project, applies the SQL bundle, verifies schema/seed, and uploads non-secret artifacts (including `project_ref`).

### Step 2: Apply the SQL Bundle (Migration + Seed)

Bundle to apply (paste-ready):
- `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`

Preflight verify bundle integrity locally (no creds needed):

```bash
cd projects/security-questionnaire-autopilot
node scripts/verify-dashboard-sql-bundle.mjs --bundle supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

Apply path A (no CLI, recommended): Supabase Dashboard -> SQL Editor
- Paste and run the entire bundle file once.

Apply path B (repeatable, no local Node version issues): GitHub Actions
- Workflow (apply + verify): `.github/workflows/cycle-005-supabase-apply.yml`
- Required secret in GitHub: `SUPABASE_DB_URL` (legacy path)

Apply path B2 (provision + apply + verify; recommended when local machine has no Supabase env vars):
- Workflow: `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`
- Required secrets in GitHub: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_ORG_SLUG`, `SUPABASE_DB_PASSWORD`

Apply path C (direct DB apply from this machine, if you have DB URL):

```bash
cd projects/security-questionnaire-autopilot
SUPABASE_DB_URL="postgresql://postgres:***@db.<project_ref>.supabase.co:5432/postgres" \
  node scripts/apply-supabase-sql.mjs supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

Apply path D (direct DB apply from this machine, deterministic inputs; avoids pasting DB URL):

```bash
cd projects/security-questionnaire-autopilot
SUPABASE_PROJECT_REF="<project_ref>" SUPABASE_DB_PASSWORD="***" ./scripts/apply-supabase-bundle.sh
```

### Step 3: Set Hosted Runtime Env Vars, Redeploy, Verify

Set on the provider that runs the Next.js workflow runtime:
- `NEXT_PUBLIC_SUPABASE_URL="https://<project_ref>.supabase.co"`
- `SUPABASE_SERVICE_ROLE_KEY="***"`

Then redeploy and verify:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq .
curl -sS "<BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```

Expected from `supabase-health`:
- `.ok == true`
- `.schema.actual_schema_bundle_id == "20260213_cycle003_hosted_workflow"`
- `.seed.present == true` (seed row `pilot-001-live-2026-02-13`)

## Rollback / Safety Note

The shipped migration uses `create table if not exists` and `create index if not exists`, so applying the bundle is low-risk and idempotent.

If you must roll back (destructive), drop tables in reverse dependency order (run in Supabase SQL Editor):

```sql
drop table if exists public.workflow_events;
drop table if exists public.pilot_deals;
drop table if exists public.workflow_runs;
drop table if exists public.workflow_app_meta;
```

## Next Action

Obtain the target Supabase `project_ref` plus hosted runtime `BASE_URL`, then apply `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql` and confirm `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `{ ok:true }`.
