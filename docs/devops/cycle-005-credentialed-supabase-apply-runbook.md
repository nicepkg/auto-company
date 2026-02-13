# Cycle 005 Credentialed Supabase Apply Runbook

Date: 2026-02-13

Goal: apply schema + seed to the target Supabase project, then prove hosted runs persist `workflow_runs` and `workflow_events`.

## Inputs (Do Not Commit Secrets)

- `BASE_URL` (deployed hosted workflow API base, e.g. `https://<app-domain>`; discovery helper: `docs/devops/base-url-discovery.md`)
- `NEXT_PUBLIC_SUPABASE_URL` (project URL)
- `SUPABASE_SERVICE_ROLE_KEY` (server-side key; required for persistence + evidence)
- `SUPABASE_DB_URL` (optional; only needed if applying SQL via `node + pg` or `psql`)

Project assets:
- Paste-ready bundle (migration + seed): `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
- Migration: `projects/security-questionnaire-autopilot/supabase/migrations/20260213_cycle003_hosted_workflow.sql`
- Seed: `projects/security-questionnaire-autopilot/supabase/seed/pilot-001-floor-pricing.sql`
- Dashboard evidence queries (no creds needed beyond Dashboard access): `docs/devops/cycle-005-dashboard-sql-evidence-queries.sql`

## Secret Handling (Recommended)

- Prefer setting `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` in your hosting provider environment UI (not in a local shell).
- If you must use a local shell for `SUPABASE_DB_URL`:
  - Use a short-lived subshell (`( export SUPABASE_DB_URL=...; <command> )`) so it does not linger in your session.
  - Avoid pasting secrets into terminals with history enabled.

## Node Version Pin

- Project pin: `projects/security-questionnaire-autopilot/.nvmrc`
- If you use `nvm`:
  - `cd projects/security-questionnaire-autopilot && nvm use`

## Step 1: Apply Migration + Seed (Choose One)

### Option A: Supabase Dashboard SQL Editor (Recommended When No CLI/psql)

1. Open Supabase project.
2. SQL Editor: create a new query.
3. Paste + run the bundle SQL file contents (preferred):
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
   - Note: the bundle ends with optional `select` verification queries, so you should see table/seed results immediately after running.
4. Optional preflight (prevents stale bundle mistakes):
   - From `projects/security-questionnaire-autopilot/` run:

```bash
node scripts/verify-dashboard-sql-bundle.mjs \
  --bundle supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

   - If this fails, rebuild the bundle (Step 3b) before pasting into the Dashboard SQL Editor.
5. If you cannot use the bundle for any reason, paste + run in two steps:
   - Migration: `projects/security-questionnaire-autopilot/supabase/migrations/20260213_cycle003_hosted_workflow.sql`
   - Seed: `projects/security-questionnaire-autopilot/supabase/seed/pilot-001-floor-pricing.sql`

### Option B: Node + `pg` (Preferred If You Have a DB URL But No `psql`)

This repo ships a SQL apply helper that does not require `psql` or the Supabase CLI:

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot

# Required:
#   export SUPABASE_DB_URL="postgresql://postgres:...@db.<project-ref>.supabase.co:5432/postgres"

node scripts/apply-supabase-sql.mjs supabase/migrations/20260213_cycle003_hosted_workflow.sql
node scripts/apply-supabase-sql.mjs supabase/seed/pilot-001-floor-pricing.sql
```

### Option C: `psql` (If Available in the Credentialed Runtime)

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot

# Required:
#   export SUPABASE_DB_URL="postgresql://postgres:...@db.<project-ref>.supabase.co:5432/postgres"

psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20260213_cycle003_hosted_workflow.sql
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/seed/pilot-001-floor-pricing.sql
```

### Option D: GitHub Actions (Workflow Dispatch; Optional)

If you want an auditable, repeatable, one-click SQL apply without relying on the Dashboard SQL Editor, this repo includes:
- `.github/workflows/cycle-005-supabase-apply.yml`

Requirements:
- Set GitHub Actions secret `SUPABASE_DB_URL` (treat as production secret).
- Trigger the workflow manually (`workflow_dispatch`) and point it at the bundle path.

### Option E: GitHub Actions (Run Hosted Workflow + Append Evidence PR; Recommended)

If you want an auditable, one-click run that:
- calls the deployed hosted API (`env-health`, `supabase-health`)
- runs a customer-originated hosted intake
- fetches DB persistence evidence (`workflow_runs` + `workflow_events`)
- uploads evidence as workflow artifacts
- and creates a PR that appends the evidence entry into the sales ledger

this repo includes:
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

Requirements:
- Provide the deployed `base_url` as a workflow input.
- If you are unsure which domain is the workflow API (vs marketing site), use: `docs/devops/base-url-discovery.md`.
- Ensure the hosted runtime already has `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` set (so `/api/workflow/env-health` and persistence work).
- Optional (only if you want the workflow to apply SQL too): set GitHub Actions secret `SUPABASE_DB_URL` and run with `skip_sql_apply=false`.
- Optional (fallback evidence fetch): set GitHub Actions secrets `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.

## Step 2: Verify Tables Exist (SQL)

Run in SQL Editor (or use the query block in `docs/devops/cycle-005-dashboard-sql-evidence-queries.sql`):

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('workflow_app_meta', 'workflow_runs', 'workflow_events', 'pilot_deals')
order by table_name;
```

Expected: all four tables are present.

Also confirm the schema bundle ID (this is what `/api/workflow/supabase-health` validates by default):

```sql
select meta_key, meta_value, updated_at
from public.workflow_app_meta
where meta_key = 'schema_bundle_id';
```

Expected: `meta_value = '20260213_cycle003_hosted_workflow'`.

## Step 3: Verify Seed Row Exists (SQL)

```sql
select run_id, status, citation_gate_passed, approval_gate_passed, reviewer, created_at, updated_at
from public.workflow_runs
where run_id = 'pilot-001-live-2026-02-13';
```

Expected: one row.

## Step 3b: Optional - Rebuild Bundle (Keeps Bundle Deterministic)

If you edited migration/seed and want to regenerate the paste-ready bundle:

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot
npm run -s supabase:bundle
```

## Step 4: Run Hosted Customer Intake With DB Persistence Enabled

In the hosted runtime environment (where Next.js runs), set:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

### Setting Hosted Env Vars (Avoid Manual Copy/Paste Where Possible)

Preferred: set env vars in the deployment platform UI/secret store, then verify via `env-health`.

Optional (if your platform supports CLI-based env management and you are authenticated):
- Vercel (example):
  - `vercel env add NEXT_PUBLIC_SUPABASE_URL production`
  - `vercel env add SUPABASE_SERVICE_ROLE_KEY production`
- Cloudflare Pages (example):
  - use `wrangler pages secret put <NAME>` for secrets, and dashboard/CI vars for public vars

Optional preflight (no secrets returned):

```bash
BASE_URL="https://<your-hosted-app-domain>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Expected:
- `.ok=true`
- `.env.NEXT_PUBLIC_SUPABASE_URL=true`
- `.env.SUPABASE_SERVICE_ROLE_KEY=true`

Then execute a customer-originated hosted run and capture evidence.

Optional preflight (verifies env vars are present and tables are queryable without leaking secrets):

```bash
BASE_URL="https://<your-hosted-app-domain>"
curl -sS "$BASE_URL/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```

If calling a deployed endpoint:

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot

# BASE_URL should be the deployed API root, e.g. https://<app-domain>
BASE_URL="https://<your-hosted-app-domain>"
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"

./scripts/hosted-workflow-customer-intake.sh "$BASE_URL" "$RUN_ID" "/tmp/hosted-intake-$RUN_ID"
```

Evidence to capture:
- `/tmp/hosted-intake-$RUN_ID/responses/06-db-evidence.json` (and `.pretty`) showing:
  - `workflowRun.run_id = <RUN_ID>`
  - `workflowEvents` contains steps: `ingest`, `draft`, `approve`, `export` (+ optionally `validate-pilot-deal`)

## Step 4b: One Command (Preferred)

This wrapper:
- (optionally) applies the SQL (if `SUPABASE_DB_URL` is provided and `SKIP_SUPABASE_SQL_APPLY` is not set)
- runs the hosted workflow
- captures DB evidence via the hosted `/api/workflow/db-evidence` endpoint
- validates evidence
- appends an entry to the sales execution ledger

```bash
cd /home/zjohn/autocomp/auto-company

BASE_URL="https://<your-hosted-app-domain>"
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"

# If SQL was applied via Dashboard SQL Editor:
export SKIP_SUPABASE_SQL_APPLY=1

./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"
```

## Step 5: Capture DB Evidence (No Next.js Required)

If you have credentials locally, you can fetch DB evidence directly:

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot
export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

RUN_ID="pilot-001-customer-originated-db-<ts>"
node scripts/fetch-supabase-workflow-evidence.mjs --run-id "$RUN_ID" --out "/tmp/db-evidence-$RUN_ID.json"

# Alternate (requires node_modules / @supabase/supabase-js):
node scripts/fetch-db-evidence.mjs "$RUN_ID" "/tmp/db-evidence-alt-$RUN_ID.json"
```

## Failure Triage

- `Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.`:
  - persistence is disabled; DB evidence will be empty or `/api/workflow/db-evidence` will return 400.
- Migration fails on `create extension pgcrypto`:
  - confirm the Supabase SQL editor is connected to the project database with sufficient permissions.
- `/api/workflow/db-evidence` returns 500:
  - table likely not created, or RLS/policies misconfigured; verify Step 2.

## Next Action
Obtain production Supabase credentials, apply migration+seed via SQL Editor, run one hosted customer intake with `SUPABASE_SERVICE_ROLE_KEY` set, and attach `db-evidence` JSON output to `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.
