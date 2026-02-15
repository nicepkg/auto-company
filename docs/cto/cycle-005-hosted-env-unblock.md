# Cycle 005: Hosted Supabase Env Unblock (Vercel)

Problem (observed 2026-02-13):
- The deployed Next.js workflow runtime serving `/api/workflow/*` was missing hosted env vars:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- This blocks `.github/workflows/cycle-005-hosted-persistence-evidence.yml` at the `env-health` gate.

What We Shipped:
- A best-effort automation path in the evidence workflow to:
  1. Detect missing env vars via `GET <BASE_URL>/api/workflow/env-health`
  2. Upsert env vars into the Vercel Project via Vercel REST API
  3. Trigger a redeploy via Vercel REST API
  4. Poll until `env-health` reports both vars present

Security Posture:
- Secrets are never printed.
- `env-health` exposes only booleans (presence), not values.
- `SUPABASE_SERVICE_ROLE_KEY` is written to Vercel as `type=sensitive`.

Operator Inputs (one-time):
- GitHub Actions secrets:
  - `VERCEL_TOKEN`
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- GitHub Actions variables:
  - `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
  - optional: `VERCEL_TEAM_ID` / `VERCEL_TEAM_SLUG`

Runbook:
- `docs/devops/cycle-005-hosted-runtime-env-vars.md`
- `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md`
- `docs/qa/cycle-005-hosted-persistence-evidence-preflight.md`

