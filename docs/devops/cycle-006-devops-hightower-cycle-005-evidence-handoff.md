# Cycle 006 (DevOps Hightower): Unblock Cycle 005 Hosted Evidence Workflow

Target: safely run `.github/workflows/cycle-005-hosted-persistence-evidence.yml` in the canonical repo, starting with a preflight-only dispatch to validate BASE_URL + hosted env, then enabling scheduled runs, then generating the evidence PR.

## Maintainer-Ready Sequence (Low Risk)

1. Merge `.github/workflows/cycle-005-hosted-persistence-evidence.yml` into the default branch.
2. Set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (2-4 deployed origins for the Next.js workflow runtime serving `/api/workflow/*`).
3. Run manual dispatch with `preflight_only=true` (green/red signal).
4. Once preflight is green, enable the schedule gate:
   - Set repo variable `CYCLE_005_AUTORUN_ENABLED=true`, or
   - Re-run preflight with `enable_autorun_after_preflight=true` (workflow will upsert the variable after a green preflight).
5. Run manual dispatch with `preflight_only=false` to generate/update the PR on branch `cycle-005-hosted-persistence-evidence`.

## Required Repo Settings (One-Time)

- Repo -> Settings -> Actions -> General -> Workflow permissions: `Read and write permissions`
- Repo -> Settings -> Actions -> General: allow GitHub Actions to create and approve pull requests (wording varies)

Why: the workflow can upsert Actions variables (candidates + schedule gate) and uses `peter-evans/create-pull-request` to open/update the evidence PR.

## Required Inputs / Variables / Secrets By Run Mode

Preflight-only (`preflight_only=true`):

- Required:
  - One of:
    - repo var `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, or
    - workflow dispatch input `base_url` / `base_url_candidates`
  - Hosted runtime must already be deployed and must pass:
    - `GET <BASE_URL>/api/workflow/env-health` with `ok=true`
    - `env.NEXT_PUBLIC_SUPABASE_URL=true` and `env.SUPABASE_SERVICE_ROLE_KEY=true` (hosting provider env vars)
  - If `skip_sql_apply=true` (default), Supabase must already have the expected schema + seed, because preflight calls:
    - `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`
- Optional (automation):
  - Persist candidates from dispatch: input `persist_base_url_candidates=true` (workflow upserts `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`)
  - Auto-enable schedule gate after green preflight: input `enable_autorun_after_preflight=true` (workflow upserts `CYCLE_005_AUTORUN_ENABLED=true`)
  - Vercel env auto-fix (best-effort):
    - Secrets: `VERCEL_TOKEN`, `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
    - Vars: `VERCEL_PROJECT_ID` (or `VERCEL_PROJECT`)
  - Cloudflare Pages env auto-fix (best-effort):
    - Secrets: `CLOUDFLARE_API_TOKEN`, `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
    - Vars: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`

Full evidence (`preflight_only=false`, creates PR):

- Required:
  - Everything from preflight-only
  - If `skip_sql_apply=false`: secret `SUPABASE_DB_URL`
- Optional (fallback evidence path):
  - If you set input `require_fallback_supabase_secrets=true`, you must also set secrets:
    - `NEXT_PUBLIC_SUPABASE_URL`
    - `SUPABASE_SERVICE_ROLE_KEY`

## Footguns / Risk Flags

- Wrong BASE_URL: candidates must be the deployed Next.js workflow runtime (not a marketing/static site). Guardrail is `/api/workflow/env-health`.
- Hosted env vars vs GitHub secrets: `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` must exist in the hosting provider env for the deployed runtime; GitHub secrets do not configure the deployed app.
- Vercel auto-fix is enabled by default (`attempt_vercel_env_sync=true`) but only activates if `VERCEL_TOKEN` + project vars are present; if enabled, it will upsert env vars and trigger redeploy (best-effort).
- Schedule PR spam: schedule trigger is gated by repo var `CYCLE_005_AUTORUN_ENABLED=true`. Do not set it until preflight is green.
- Permissions: if the repo’s Actions “Workflow permissions” remain read-only, variable upserts and PR creation can fail.

## Where To Look When It Fails

- Download artifact `cycle-005-hosted-preflight` and inspect:
  - `preflight/base-url-probe.txt`
  - `preflight/env-health.json`
  - `preflight/supabase-health.json`

## References (Repo Docs)

- `docs/devops/cycle-005-hosted-persistence-evidence-maintainer-quickstart.md`
- `docs/devops/cycle-005-hosted-persistence-evidence-checklist.md`
- `docs/devops/cycle-005-gha-base-url-and-secrets-runbook.md`
- `docs/devops/cycle-005-hosted-runtime-env-vars.md`
- `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md`

Next Action: merge `.github/workflows/cycle-005-hosted-persistence-evidence.yml`, set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, then run a manual dispatch with `preflight_only=true`.

