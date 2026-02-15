# Cycle 003 Hosted Next.js + Supabase Implementation

## Scope Shipped
Implemented a hosted workflow wrapper in `projects/security-questionnaire-autopilot/` that preserves the validated hard gates by executing the existing Python engine through Next.js API routes.

## Hosted Endpoints
- `POST /api/workflow/validate-pilot-deal`
- `POST /api/workflow/ingest`
- `POST /api/workflow/draft`
- `POST /api/workflow/approve`
- `POST /api/workflow/export`

## Gate Enforcement
- Citation gate: validated in draft route via `evaluateCitationGate` and reflected in response/status.
- Human approval gate: required in approve + export routes; export calls `assertExportReady` before CLI export.
- Pricing/margin gate: enforced through `validate-pilot-deal` using shared floor constants and margin calculation.

## Supabase Integration
- Optional, env-driven persistence via:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- `workflow_runs` receives latest run status and gate flags.
- `workflow_events` logs each workflow step success/failure.

## Files Added (Hosted Layer)
- `projects/security-questionnaire-autopilot/app/api/workflow/*/route.ts`
- `projects/security-questionnaire-autopilot/lib/workflow/runtime.ts`
- `projects/security-questionnaire-autopilot/lib/workflow/normalizers.ts`
- `projects/security-questionnaire-autopilot/lib/supabase/workflow-repo.ts`
- `projects/security-questionnaire-autopilot/supabase/migrations/20260213_cycle003_hosted_workflow.sql`
- `projects/security-questionnaire-autopilot/supabase/seed/pilot-001-floor-pricing.sql`
- `projects/security-questionnaire-autopilot/scripts/hosted-workflow-smoke.sh`

## Next Action
Run the hosted smoke path against a live Supabase project and attach the first customer-originated hosted run ID + export manifest to sales/ops trackers.
