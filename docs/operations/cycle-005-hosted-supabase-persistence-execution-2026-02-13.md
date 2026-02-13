# Cycle 005 Hosted Supabase Persistence Execution (Ops)

Date: 2026-02-13
Owner (ops): operations-pg

## Stage Diagnosis
- Product stage: pre-PMF, but active paid pilot.
- Constraint: sales acceptance requires auditability (DB persistence evidence) before broader customer delivery.

## Objective
Apply the hosted workflow migration + seed to the target Supabase project, configure the hosted runtime Supabase env vars, execute one customer-originated hosted run, and attach run-id-specific DB evidence (`workflow_runs` + `workflow_events`) into `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.

## What I Did (Concrete Deliverables)
- Verified the paste-ready SQL bundle exists and is deterministic:
  - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
- Reduced a common hosted-run footgun (double-slash API URLs) by normalizing `BASE_URL`:
  - patched `projects/security-questionnaire-autopilot/scripts/hosted-workflow-customer-intake.sh`
- Tightened the wrapper’s operator signal (so the health check meaning matches behavior):
  - patched log text in `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh`
- Updated DevOps docs to make expected preflight results explicit:
  - patched `docs/devops/cycle-005-credentialed-supabase-apply-runbook.md`
  - patched `docs/devops/cycle-005-supabase-migration-and-persistence-runbook.md`

## Current Status
Blocked in this runtime due to missing hosted environment inputs:
- Hosted `BASE_URL` (deployed Next.js domain) is not present in repo docs/config.
- Supabase credentials are not present in environment:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - optional `SUPABASE_DB_URL` if applying SQL outside the Dashboard SQL Editor

Without these, we cannot:
- apply the migration + seed to the correct hosted Supabase project
- confirm hosted persistence via `GET /api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`
- generate and append the run-id-specific DB evidence entry into the sales execution ledger

## Why This Matters (Ops Lens)
- The fastest path to expansion is trust: persistence evidence reduces “is this real / auditable?” friction during customer security review.
- Until this is unblocked, each “pilot run” creates file artifacts but not durable audit trails, weakening the story for procurement.

## Execution Command (Once Creds + BASE_URL Exist)
1) Apply migration + seed (choose one):
- Dashboard SQL Editor (preferred): paste and run:
  - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
- OR direct apply via Postgres URL (credentialed shell):
  - set `SUPABASE_DB_URL` and let the wrapper apply SQL automatically.

2) Ensure hosted runtime env vars are set (on the deployment platform) and redeployed:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

3) Run the wrapper (from repo root):
```bash
BASE_URL="https://<your-hosted-app-domain>"
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"

# If SQL already applied via Dashboard SQL Editor:
export SKIP_SUPABASE_SQL_APPLY=1

./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"
```

Expected outputs on success:
- `docs/qa/cycle-005-env-health-<run_id>.json`
- `docs/qa/cycle-005-supabase-health-<run_id>.json`
- `docs/devops/cycle-005-supabase-persistence-<run_id>.json`
- auto-appended entry in `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` under “Cycle 005 DB Persistence Evidence Log”

## Traps To Avoid
- Wrong Supabase project: the wrapper’s `supabase-health` call requires the known seed run (`pilot-001-live-2026-02-13`) to be present, which is the fastest mismatch detector.
- Hosted env vars set but not redeployed: `env-health` will still show `false` until a redeploy/restart picks up the variables.

## Next Action
Obtain the real hosted `BASE_URL` and Supabase credentials (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and optionally `SUPABASE_DB_URL`), then run `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh` once to append DB evidence into `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.

