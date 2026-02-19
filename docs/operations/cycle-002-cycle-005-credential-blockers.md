# Cycle 002: Cycle 005 Credential Blockers (This Workspace)

Date: 2026-02-13

## Summary

Cycle 2 decision is **GO (conditional)** on Security Questionnaire Autopilot, but **we must produce Cycle 005 hosted Supabase persistence evidence** before scaling onboarding/sales.

This workspace currently cannot run the automated env-sync and evidence workflows end-to-end due to missing credentials and missing production `BASE_URL`.

## What Is Missing

- GitHub permissions:
  - `gh repo view` reports `nicepkg/auto-company` viewer permission is `READ`.
  - `make cycle-005-env-sync` and `make cycle-005-evidence` require dispatching workflows, which needs >= `WRITE`.
- Hosting provider credentials (local shell):
  - No local `VERCEL_TOKEN` / `CLOUDFLARE_API_TOKEN` or related IDs are set, so local provider API scripts cannot upsert env vars or redeploy.
- Supabase env values (local shell):
  - No local `NEXT_PUBLIC_SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are set, so local sync cannot proceed.
- Production `BASE_URL` candidates:
  - GitHub Deployments metadata discovery returned no URLs (repo does not publish deployments).
  - Prior guessed `*.vercel.app` candidates returned `DEPLOYMENT_NOT_FOUND`; prior `*.pages.dev` candidates did not resolve or were not the workflow runtime.

## Required Outcome

The deployed Next.js workflow runtime `BASE_URL` must satisfy:

- `GET <BASE_URL>/api/workflow/env-health` returns `200` JSON with:
  - `ok=true`
  - `env.NEXT_PUBLIC_SUPABASE_URL=true`
  - `env.SUPABASE_SERVICE_ROLE_KEY=true`

## Recommended Fix Path (Maintainer)

1. Identify the real production runtime origins from the hosting provider:
   - Custom domain and provider domain (2-4 candidates).
2. Ensure hosted runtime has the two Supabase env vars set for Production (Preview optional but recommended), then redeploy.
3. Run (from a maintainer shell):
   - `make cycle-005-env-sync`
   - `make cycle-005-evidence`

Reference runbooks:
- `docs/operations/cycle-005-hosted-runtime-env-vars.md`
- `docs/operations/cycle-005-hosted-persistence-evidence-operator-runbook.md`
- `docs/devops/cycle-005-gha-base-url-and-secrets-runbook.md`

