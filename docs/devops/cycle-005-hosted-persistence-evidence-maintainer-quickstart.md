# Cycle 005 Hosted Persistence Evidence: Maintainer Quickstart (DevOps)

Goal: a maintainer can reliably:
- set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- run a manual dispatch with `preflight_only=true`
- enable scheduled refresh by setting `CYCLE_005_AUTORUN_ENABLED=true` only after a green preflight

Primary workflow: `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

## 0) Required Repo Settings (One-Time)

These must be enabled or “persist candidates”, “enable autorun after preflight”, scheduled runs, and PR creation may fail:

- Repo -> Settings -> Actions -> General -> Workflow permissions: `Read and write permissions`
- Repo -> Settings -> Actions -> General: allow GitHub Actions to create and approve pull requests (wording varies by GitHub UI)

## Config Matrix (Preflight-Only vs Full Evidence)

Preflight-only (`preflight_only=true`, default for manual dispatch):

- Required:
  - Either workflow input candidates (`base_url` / `base_url_candidates`) or repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
  - Hosted runtime must already be deployed and must pass:
    - `GET <BASE_URL>/api/workflow/env-health` -> `ok=true`
    - `env.NEXT_PUBLIC_SUPABASE_URL=true` and `env.SUPABASE_SERVICE_ROLE_KEY=true` (hosting provider env vars, not GitHub secrets)
  - If `skip_sql_apply=true` (default), Supabase must already have the expected schema + seed (preflight runs `supabase-health`)
- Optional:
  - Persist candidates from the dispatch: `persist_base_url_candidates=true` (workflow upserts `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`)
  - Auto-enable schedule gate after a green preflight: `enable_autorun_after_preflight=true` (workflow upserts `CYCLE_005_AUTORUN_ENABLED=true`)
  - Vercel auto-fix missing hosted env vars (best-effort):
    - Secrets: `VERCEL_TOKEN`, `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
    - Vars: `VERCEL_PROJECT_ID` (or `VERCEL_PROJECT`)
  - Cloudflare Pages auto-fix missing hosted env vars (best-effort):
    - Secrets: `CLOUDFLARE_API_TOKEN`, `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
    - Vars: `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`

Full evidence (`preflight_only=false`, creates PR):

- Required:
  - Everything from preflight-only
  - If `skip_sql_apply=false`: GitHub secret `SUPABASE_DB_URL`
- Optional:
  - Fallback direct evidence fetch secrets (only if you choose to enforce it):
    - Set `require_fallback_supabase_secrets=true` and provide secrets `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

## 1) Set BASE_URL Candidates (Once)

These must be 2-4 origins for the deployed Next.js runtime that serves `/api/workflow/*` (not a marketing/static site).

Option A (UI): repo -> Settings -> Secrets and variables -> Actions -> Variables
- Name: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- Value: `https://app-1.example.com https://app-2.example.com`

Option B (CLI):

```bash
REPO="OWNER/REPO"
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body \
  "https://app-1.example.com https://app-2.example.com"
```

Option C (Workflow UI, persists automatically):
1. Actions -> `cycle-005-hosted-persistence-evidence` -> Run workflow
2. Set `base_url` to your candidate list
3. Set `persist_base_url_candidates=true`

## 2) Run A Manual Preflight (Green/Red Signal)

Actions -> `cycle-005-hosted-persistence-evidence` -> Run workflow:
- `preflight_only=true`
- Leave `base_url` empty if you already set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`

Pass criteria:
- BASE_URL is selected (job summary)
- `env-health` passes
- `supabase-health` passes (when `skip_sql_apply=true`, which is the default)

## 3) Enable Scheduled Refresh (Only After Green Preflight)

Option A (Workflow UI, recommended):
- When running the preflight (step 2), set `enable_autorun_after_preflight=true`

Option B (CLI):

```bash
REPO="OWNER/REPO"
gh variable set CYCLE_005_AUTORUN_ENABLED -R "$REPO" --body true
```

Notes:
- Schedule runs are gated behind `CYCLE_005_AUTORUN_ENABLED=true` to prevent PR spam.
- After you enable the gate, the cron trigger will refresh evidence every ~6 hours.

## Run Evidence (Creates PR)

After preflight is green, run again with `preflight_only=false` to generate the evidence PR.

Preferred CLI wrapper:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --skip-sql-apply true
```
