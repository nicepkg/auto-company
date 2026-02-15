# Cycle 005 Hosted Persistence Evidence: QA Notes (2026-02-14)

## Preflight Acceptance (Green = Safe To Enable Autorun)
Preflight is considered green when all of the following are true:
- A single `BASE_URL` is selected from candidates.
- `GET <BASE_URL>/api/workflow/env-health` returns:
  - HTTP `200`
  - JSON parseable
  - `.ok == true`
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`
- When `skip_sql_apply=true` (default), `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns:
  - HTTP `200`
  - `.ok == true`
  - Schema bundle ids do not show unexpected drift (`expected` vs `actual`)

## Evidence Run Acceptance (Green = Evidence PR Should Be Mergeable)
- Workflow wrapper completes successfully.
- Post-run smoke passes (`preflight/postrun/smoke-summary.json` has `.ok == true`).
- `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` includes an entry containing the emitted `run_id=...`.
- An evidence PR exists (or is updated) on branch `cycle-005-hosted-persistence-evidence`.

## Negative Tests (Common Breakages)
- Wrong domain in candidates:
  - Symptom: `env-health` returns HTML or non-JSON.
  - Fix: update `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to the deployed Next.js runtime that serves `/api/workflow/*`.
- Hosted runtime missing Supabase env:
  - Symptom: env-health ok but `.env.*` booleans are false.
  - Fix: set hosting env vars and redeploy.
- Supabase schema/seed not applied (when `skip_sql_apply=true`):
  - Symptom: `supabase-health` fails.
  - Fix: apply SQL bundle to the correct Supabase project (or run with `skip_sql_apply=false` + `SUPABASE_DB_URL` secret).

## Artifact Triage Pointers
- `cycle-005-hosted-base-url-probe`: quickest way to see which candidates are wrong and why.
- `cycle-005-hosted-preflight/env-health*.json`: authoritative view of hosted runtime env readiness.
- `cycle-005-hosted-preflight/supabase-health.json`: authoritative view of DB schema/seed readiness.

