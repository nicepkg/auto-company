# Cycle 016: Automate Vercel Env Sync For Cycle 005 Evidence Runs

Date: 2026-02-13

## Objective

Remove the manual Vercel dashboard step when Cycle 005 evidence runs fail because the hosted Next.js runtime (serving `/api/workflow/*`) is missing:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

## Shipped

- GitHub Actions workflow `.github/workflows/cycle-005-hosted-persistence-evidence.yml` now supports best-effort auto-fix on Vercel:
  - upsert Supabase env vars via Vercel REST API
  - trigger redeploy via Vercel REST API (no deploy hook required)
  - poll `GET <BASE_URL>/api/workflow/env-health` until env is present (10m timeout)
- New script:
  - `projects/security-questionnaire-autopilot/scripts/vercel-sync-supabase-env.sh`
- New runbook:
  - `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md`

## Security / Blast Radius

- No secret values are printed in CI logs; the health endpoint returns booleans only.
- Automation is gated on explicit secrets/vars being configured (`VERCEL_TOKEN`, Vercel project id/name, and Supabase secrets).
- The change mutates Vercel project configuration only when the workflow run hits the missing-env condition and automation is enabled.
