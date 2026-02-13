# Cycle 011: Operator Checklist (Pick Correct BASE_URL + Run GHA Evidence Safely)

Goal: run `.github/workflows/cycle-005-hosted-persistence-evidence.yml` against the real deployed Next.js workflow runtime (not a marketing/static site) and produce a PR that appends persistence evidence.

## 1) Confirm What Can And Cannot Be Determined From This Repo

- Canonical hosted `BASE_URL`: cannot be determined from repo.
- Deterministic validation: available via `GET <BASE_URL>/api/workflow/env-health` (must return `200` JSON with `{ ok: true }`), plus additional Supabase env presence checks used by CI.

## 2) Identify Candidate BASE_URLs (Provider UI)

Pick 2-4 candidates from your hosting provider for the deployed Next.js app that contains the workflow runtime:

- Vercel:
  - Open the Vercel Project that corresponds to the workflow app (not the marketing site).
  - Copy the production domain (custom domain and/or `*.vercel.app` domain).
- Cloudflare Pages:
  - Open the Pages project for the workflow app.
  - Copy the production `*.pages.dev` domain and any custom domain.

Pass criteria:
- Candidate is an origin (no path), e.g. `https://app.example.com`
- Bare domains like `app.example.com` also work (the discovery script assumes `https://`)
- Candidate is the app that should serve `app/api/workflow/*`

Fail criteria:
- Domain is clearly marketing (often `www`, landing-page repo, or returns HTML for `/api/*`)

## 3) Ensure Hosted Runtime Env Vars Are Set And Deployed

The workflow’s `BASE_URL` discovery script rejects a runtime that is reachable but missing these env vars.

On the hosting provider for the workflow app, set:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Then redeploy/restart so the running deployment actually sees the new env vars.

Pass criteria:
- After redeploy, `GET <BASE_URL>/api/workflow/env-health` returns `200` JSON where:
  - `.ok == true`
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Fail criteria:
- `404` / DNS failure
- Non-JSON response (common when you hit the marketing/static site)
- JSON response but env booleans are `false` (env vars not set, or deployment not restarted)

Local operator probe (recommended):
```bash
BASE_URL="https://<candidate-domain>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

## 4) Set GitHub Actions Secrets (Repo Settings)

In GitHub: `Settings -> Secrets and variables -> Actions -> New repository secret`

Conditionally required:
- `SUPABASE_DB_URL` only if you will run with `skip_sql_apply=false`

Optional (fallback-only; avoid unless hosted DB evidence is unreliable):
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Pass criteria:
- Workflow run does not fail at “Preflight: required secrets”

Fail criteria:
- Any secret missing or empty (workflow exits with explicit message)

## 5) Trigger The Evidence Workflow (Workflow Dispatch)

Run: `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

Inputs:
- `base_url`: optional. If set, provide candidates separated by commas/spaces/newlines, example:
  - `https://app.example.com https://app.vercel.app https://www.example.com`
  - `app.example.com app.vercel.app www.example.com`
  - If you leave this empty, set repo variable `CYCLE_005_BASE_URL_CANDIDATES` once and re-use it for every run.
  - If neither input nor variable is set, the workflow will attempt best-effort GitHub Deployments discovery (if your deploy pipeline publishes Deployments metadata).
- `run_id`: optional; if empty, CI generates a timestamped ID
- `skip_sql_apply`:
  - `true` if you already applied the SQL bundle via Supabase Dashboard SQL editor
  - `false` if you want CI to apply the SQL (requires `SUPABASE_DB_URL`)
- `sql_bundle`: only relevant when `skip_sql_apply=false`

Pass criteria (guardrails):
- Step “Discover + validate deployed BASE_URL (fail-fast)” selects a `BASE_URL` and does not error.
- Evidence artifacts upload succeeds.
- A PR is opened that includes:
  - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` updated
  - `docs/qa/cycle-005-*.json` evidence files

Fail criteria:
- Discovery fails with “no valid hosted Next.js runtime BASE_URL found.”
  - Action: re-check provider domain, and re-check `env-health` returns JSON + env booleans true.

## 6) Post-Run Sanity Checks (Avoid False Confidence)

- Verify the chosen `BASE_URL` in the workflow logs matches the intended provider project domain (not the marketing domain).
- Confirm the evidence PR references the expected `run_id` and includes `env-health` and `supabase-health` outputs.
