# Cycle 005 Unblock Plan (Supabase Persistence)

Date: 2026-02-13

Blocker: environment lacks production Supabase credentials, so DB persistence for hosted workflow cannot be proven yet.

## Owner

- Primary: `devops-hightower`
- Secondary: `fullstack-dhh`

## What Is Already Shipped

- Supabase schema assets:
  - Paste-ready bundle (migration + seed): `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
  - `projects/security-questionnaire-autopilot/supabase/migrations/20260213_cycle003_hosted_workflow.sql`
  - `projects/security-questionnaire-autopilot/supabase/seed/pilot-001-floor-pricing.sql`
- Hosted API persistence hooks (env-gated).
- DB evidence retrieval:
  - Hosted endpoint: `projects/security-questionnaire-autopilot/app/api/workflow/db-evidence/route.ts`
  - Direct script: `projects/security-questionnaire-autopilot/scripts/fetch-db-evidence.mjs`
  - Dependency-free script (Node 18+): `projects/security-questionnaire-autopilot/scripts/fetch-supabase-workflow-evidence.mjs`
- Operator runbook (BASE_URL candidates, workflow-dispatch minimal inputs):
  - `docs/operations/cycle-005-hosted-persistence-evidence-operator-runbook.md`

## Fastest Path To Close (Target: < 30 minutes once creds exist)

1. Acquire credentials for target Supabase project:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - Optional `SUPABASE_DB_URL` for SQL apply via `psql`
2. Apply migration + seed via Supabase SQL Editor (preferred):
   - paste/run `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
3. Set env vars in the hosted runtime where Next.js runs.
4. Run one customer-originated hosted intake and capture:
   - export manifest
   - `/api/workflow/db-evidence` response JSON (or output of `fetch-supabase-workflow-evidence.mjs` / `fetch-db-evidence.mjs`)
5. Attach evidence to:
   - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

## Next Action
Provide production Supabase credentials and apply migration+seed via SQL Editor, then execute one hosted customer intake with DB evidence capture.
