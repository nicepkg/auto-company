# Cycle 003 DevOps Runbook - Hosted Workflow

## Prerequisites
- Node.js 20+
- Python 3.10+
- `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (optional but required for hosted DB persistence)

## Local Bring-up
```bash
cd projects/security-questionnaire-autopilot
npm install
npm run dev
```

## Workflow Smoke
```bash
./scripts/hosted-workflow-smoke.sh http://localhost:3000
```

## Expected Result
- Pricing validation: pass at floor package.
- Ingest: run directory created under `runs/<run-id>/`.
- Draft: cited answers generated.
- Approve: `approval.json` recorded.
- Export: zip generated under `/tmp/<run-id>-hosted-export.zip`.

## Supabase Migration / Seed
- Migration SQL: `supabase/migrations/20260213_cycle003_hosted_workflow.sql`
- Seed SQL: `supabase/seed/pilot-001-floor-pricing.sql`

## Failure Handling
- Non-zero CLI exits are surfaced as 4xx responses in API routes.
- Every failed step sets run status `failed` and emits a `workflow_events` failure row when Supabase is configured.

## Next Action
Apply migration + seed on hosted Supabase environment and run one real pilot intake through the API endpoints.
