# Cycle 005: Hosted Persistence Evidence Preflight (Operator Runbook)

Date: 2026-02-13
Role: qa-bach

Goal: make `./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh` (and the corresponding GitHub Actions workflow) fail fast with actionable fixes when `BASE_URL` or hosted Supabase env vars are missing.

## What "BASE_URL" Must Be

`BASE_URL` must be the deployed **Next.js app origin** that serves the workflow API routes under `app/api/workflow/*`.

Sanity check:
- `GET <BASE_URL>/api/workflow/env-health` returns JSON with `ok=true`.

Common wrong value:
- marketing/static domains that return HTML or `404` for `/api/workflow/env-health`.

## Quick Start (Recommended)

1) Set the repo variable once (preferred):

UI path (works even if `gh` is permission-limited):
- GitHub repo -> Settings -> Secrets and variables -> Actions -> Variables
- Add/update variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` with `https://candidate1 https://candidate2`

CLI path (only if your GitHub token has permission):

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R OWNER/REPO --body "https://candidate1 https://candidate2"
```

2) Run the evidence runner:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO
```

Recommended: run a preflight-only dispatch first (no evidence, no PR):
```bash
make cycle-005-preflight
```

After a green preflight, enable scheduled refresh (prevents manual babysitting):
```bash
make cycle-005-preflight-enable-autorun
```

If you do not want to persist candidates into the repo variable, pass them for a single run:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO --base-url "https://candidate1 https://candidate2"
```

## Where BASE_URL Usually Comes From

- Vercel: your production deployment domain (for the app), e.g. `https://<project>.vercel.app` or your custom app domain.
- Cloudflare Pages: your Pages domain, e.g. `https://<project>.pages.dev` or your custom app domain.

Tip: compare candidates quickly:

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh "https://c1 https://c2"
```

## Required Hosted Runtime Env Vars (Supabase)

The deployed runtime must have these env vars set:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

The evidence scripts probe them safely via:
- `GET <BASE_URL>/api/workflow/env-health` (never returns secret values)

Where to set them (hosted runtime, then redeploy):
- Vercel: Project -> Settings -> Environment Variables (Production at minimum), then redeploy.
- Cloudflare Pages: Project -> Settings -> Environment variables (Production), then trigger a new deployment.

Optional automation (Vercel only):
- The GitHub Actions workflow can attempt to upsert these env vars into Vercel + redeploy when `attempt_vercel_env_sync=true`.
- See: `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md`

### GitHub Actions: What It Is (and Is Not)

GitHub Actions variables/secrets are relevant to the **evidence workflow execution**, not automatically to your deployment.

- To provide candidates to the workflow without typing them each run:
  - GitHub: Repo -> Settings -> Secrets and variables -> Actions -> Variables
  - Variable name: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`

- Optional fallback (only if the hosted runtime cannot produce DB evidence and the workflow falls back to direct fetch):
  - GitHub: Repo -> Settings -> Secrets and variables -> Actions -> Secrets
  - Secrets: `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

Important: those GitHub secrets do **not** configure the hosted Next.js runtime unless your deployment pipeline explicitly maps them into the hosting provider.

## Failure Triage (Fast)

1) "Missing BASE_URL candidates"
- Fix: set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (repo variable) or pass `--base-url`.

2) "/api/workflow/env-health not JSON" or HTTP non-200
- Fix: `BASE_URL` is probably not pointing at the Next.js app runtime. Try a different domain/origin.

3) env-health returns `ok=true` but `env.*` booleans are false
- Fix: set `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` on the hosting provider and redeploy.

4) supabase-health fails (schema/seed mismatch)
- Fix: apply the expected Supabase SQL bundle, or run the evidence workflow with SQL apply enabled.

## Related

- `docs/devops/base-url-discovery.md`
- `docs/devops/cycle-005-hosted-runtime-env-vars.md`
- `docs/qa/cycle-005-hosted-base-url-discovery.md`
