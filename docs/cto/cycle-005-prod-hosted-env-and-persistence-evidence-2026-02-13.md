# Cycle 005: Production Hosted Env Vars + Redeploy + Persistence Evidence (CTO-Vogels)

Date: 2026-02-13
Repo: `nicepkg/auto-company`
Scope: `projects/security-questionnaire-autopilot` (hosted Next.js workflow API + Supabase)

## Constraints / Requirements

Goal (Definition of Done):
1. Hosted runtime (production) has Supabase env vars:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
2. A redeploy/build is triggered so the runtime actually reads the new env.
3. Cycle 005 hosted persistence evidence artifacts are produced:
   - `docs/devops/cycle-005-supabase-persistence-<run_id>.json`
   - Sales ledger appended under `## Cycle 005 DB Persistence Evidence Log` in `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

Hard gating endpoint (no secrets leaked):
- `GET <BASE_URL>/api/workflow/env-health` must return:
  - `.ok=true`
  - `.env.NEXT_PUBLIC_SUPABASE_URL=true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY=true`

## What I Could And Could Not Do From This Workspace

This workspace has:
- `gh` authenticated, but the GitHub permission on `nicepkg/auto-company` is `viewerPermission=READ`.
- No Vercel/Cloudflare CLI configured locally, and no provider tokens in local env.
- No GitHub Deployments metadata returned (so the repo cannot be used to discover a production `BASE_URL` deterministically).

Consequence:
- I cannot set hosting provider env vars, trigger redeploy, or dispatch the GitHub Actions workflows from this machine/account.
- I cannot run the Cycle 005 hosted evidence workflow end-to-end without a production `BASE_URL` and maintainer credentials.

## Concrete Deliverables Shipped (Automation / Runbook)

To minimize future operator error and reduce dashboard-clicking, I added a thin wrapper to dispatch the hosted runtime env sync workflow:
- `scripts/devops/run-cycle-005-hosted-runtime-env-sync.sh`
- Back-compat shim: `scripts/cycle-005/run-hosted-runtime-env-sync.sh`
- Make target: `make cycle-005-env-sync`

This pairs with the existing evidence runner:
- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`
- Make target: `make cycle-005-evidence`

## Recommended Execution Path (Vercel First)

Why: the repo’s automation is strongest for Vercel (REST API upsert + redeploy + polling), and it keeps secrets out of logs.

One-time (maintainer/admin required):
1. Configure GitHub Actions secrets:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `VERCEL_TOKEN`
2. Configure GitHub Actions variables:
   - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (2-4 production candidate origins)
   - `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT`
   - Optional (team scope): `VERCEL_TEAM_ID` / `VERCEL_TEAM_SLUG`

Run (maintainer with >= WRITE):
1. Sync hosted runtime env vars and redeploy:
   - `make cycle-005-env-sync`
2. Run Cycle 005 hosted persistence evidence:
   - `make cycle-005-evidence`

Expected outputs:
- The evidence workflow uploads `cycle-005-hosted-base-url-probe` artifacts (for audit/debug).
- Evidence JSON appears at `docs/devops/cycle-005-supabase-persistence-<run_id>.json` (either via PR or local branch depending on workflow behavior).

## Key Failure Modes (And Guardrails)

- Wrong `BASE_URL` (marketing/static site, preview URL, or stale deployment): caught by `/api/workflow/env-health` probe and selection workflow.
- Env var update without redeploy: guardrail is explicit redeploy and polling for env-health booleans to flip true.
- Evidence against wrong DB/schema: guardrail is schema bundle identity stamped into `workflow_runs.metadata` and enforced by evidence validation.
- Secret leakage: `env-health` returns booleans only; Vercel sync writes `SUPABASE_SERVICE_ROLE_KEY` as `type=sensitive`.

## Next Action (Handoff)

Have a maintainer (>= WRITE) supply the real production `BASE_URL` candidates and run:
1. `make cycle-005-env-sync`
2. `make cycle-005-evidence`

