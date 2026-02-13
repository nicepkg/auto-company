# Cycle 005 Hosted Supabase Persistence Execution Report (QA)

Date: 2026-02-13
Role: qa-bach
Scope: hosted Security Questionnaire Autopilot workflow (Supabase migration+seed + persisted run/event evidence)

## Objective
1. Apply Supabase migration + seed using the paste-ready SQL bundle:
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
2. Verify the hosted runtime is configured for persistence:
   - `NEXT_PUBLIC_SUPABASE_URL` set
   - `SUPABASE_SERVICE_ROLE_KEY` set
3. Execute one hosted customer-originated run and capture DB evidence:
   - `workflow_runs` row exists for the run id
   - `workflow_events` contains `ingest,draft,approve,export` with `status=success`
4. Auto-append the DB evidence entry into:
   - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

## Current Status (This Runtime)
Blocked: this environment does not contain production Supabase credentials and does not include the hosted `BASE_URL`.

Evidence:
- Existing log confirms missing creds and CLIs in this runtime:
  - `docs/devops/cycle-005-supabase-migration-attempt.txt`

Impact:
- Cannot apply SQL bundle to the target hosted Supabase project.
- Cannot run `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh` against the hosted deployment to generate run-id-specific DB evidence and append it into the sales ledger.

## Risk Notes (Why This Is High Leverage)
- The highest-cost failure mode is “schema drift”: the hosted app runs fine, but persistence evidence fails because the DB schema/bundle applied is stale or incomplete.
- The second highest-cost failure mode is “false green”: `/api/workflow/supabase-health` returns OK even though required columns/seed aren’t present.

## Hardening Delivered (To Reduce Manual Mistakes)
Changes shipped to reduce schema/evidence mismatch:

1. Stricter hosted health check:
   - `projects/security-questionnaire-autopilot/app/api/workflow/supabase-health/route.ts`
   - Now supports strict checks via query params:
     - `requireSeed=1` enforces the seed row exists (`run_id=pilot-001-live-2026-02-13`)
     - `requirePilotDeals=1` enforces `pilot_deals` is queryable (and checks representative columns)
2. Cycle-005 wrapper now enforces strict hosted health:
   - `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh`
   - Calls: `GET /api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`
3. Bundle drift guard (local preflight):
   - `projects/security-questionnaire-autopilot/scripts/verify-dashboard-sql-bundle.mjs`
   - Verifies the bundle’s embedded SHA256 header values match the current migration/seed files before anyone pastes the bundle into the Dashboard SQL Editor or applies it via `SUPABASE_DB_URL`.
4. Runbook upgraded to include the bundle verification step:
   - `docs/devops/cycle-005-credentialed-supabase-apply-runbook.md`

## Credentialed Execution (What To Run Once You Have Access)
Inputs needed:
- `BASE_URL="https://<your-hosted-app-domain>"`
- Hosted runtime env vars set in the deployment platform:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`

Fastest path (Dashboard SQL Editor apply + wrapper run):
```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot
node scripts/verify-dashboard-sql-bundle.mjs \
  --bundle supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql

# Apply the bundle via Supabase Dashboard SQL Editor (per runbook),
# then run the hosted workflow + evidence capture:
cd /home/zjohn/autocomp/auto-company
export SKIP_SUPABASE_SQL_APPLY=1
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"
./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"
```

Expected outputs on success:
- `docs/qa/cycle-005-env-health-<run_id>.json`
- `docs/qa/cycle-005-supabase-health-<run_id>.json`
- `docs/devops/cycle-005-supabase-persistence-<run_id>.json`
- Auto-appended entry in `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` under `## Cycle 005 DB Persistence Evidence Log`

## Next Action
Provide the hosted `BASE_URL` and production Supabase credentials (or confirm they are set on the hosted runtime), then run:
- `./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"`

