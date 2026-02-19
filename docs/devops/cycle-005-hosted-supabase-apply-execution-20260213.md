# Cycle 005 Hosted Supabase Apply + Evidence Execution Log

Date: 2026-02-13
Owner: devops-hightower

## Current Status

Blocked: no hosted `BASE_URL` and no Supabase credentials are available in this execution environment (all were `unset`):
- `SUPABASE_DB_URL`
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Because of that, I could not:
- apply the SQL bundle to the target Supabase project
- verify the hosted runtime has Supabase env vars configured
- run the hosted workflow against the real hosted `BASE_URL`
- capture run-id-specific DB evidence and auto-append it into `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

## Changes Shipped To Reduce Manual Steps + Prevent Schema/Evidence Mismatch

1. Added a deterministic schema identity table and seed:
   - `public.workflow_app_meta(meta_key, meta_value, updated_at)`
   - Seeded `schema_bundle_id=20260213_cycle003_hosted_workflow`

2. Hardened hosted Supabase preflight:
   - `GET /api/workflow/supabase-health` now validates `workflow_app_meta.schema_bundle_id` by default (`requireSchema=1` unless overridden).
   - This fails fast when tables exist but the wrong bundle was applied, preventing non-comparable evidence.

3. Improved evidence audit trail:
   - `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh` now:
     - passes `base_url`, `env-health`, and `supabase-health` artifacts into the sales ledger append
     - writes a deterministic metadata file: `docs/devops/cycle-005-hosted-supabase-run-metadata-<run_id>.txt`

4. Updated runbooks and dashboard evidence queries to include:
   - `workflow_app_meta` table checks
   - `schema_bundle_id` verification

## What To Run Once Creds + Hosted URL Exist

1. Apply bundle in Supabase Dashboard SQL Editor:
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`

2. Ensure the hosted Next.js runtime has:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`

3. Run the one-command wrapper from repo root:

```bash
export SKIP_SUPABASE_SQL_APPLY=1

BASE_URL="https://<your-hosted-app-domain>"
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"

./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"
```

Expected outputs:
- `docs/qa/cycle-005-env-health-<run_id>.json`
- `docs/qa/cycle-005-supabase-health-<run_id>.json` (includes schema bundle id)
- `docs/devops/cycle-005-supabase-persistence-<run_id>.json`
- `docs/devops/cycle-005-hosted-supabase-run-metadata-<run_id>.txt`
- `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` auto-appended evidence entry

## Rollback

If you must revert the schema:
1. `drop table if exists public.workflow_events;`
2. `drop table if exists public.pilot_deals;`
3. `drop table if exists public.workflow_runs;`
4. `drop table if exists public.workflow_app_meta;`

## Next Action

Provide the hosted `BASE_URL` plus Supabase credentials (at minimum `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, and optionally `SUPABASE_DB_URL`) so I can run the wrapper and generate an evidence-backed sales ledger entry for a new run ID.

