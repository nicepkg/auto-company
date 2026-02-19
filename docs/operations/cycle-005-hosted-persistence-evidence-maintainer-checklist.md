# Cycle 005 Hosted Persistence Evidence (Maintainer Checklist)

Goal: make `.github/workflows/cycle-005-hosted-persistence-evidence.yml` produce:
- evidence artifacts (`docs/qa/cycle-005-*.json`, `docs/devops/cycle-005-*.json`)
- a PR that appends to `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

This is intentionally “do things that do not scale”: one correct run proves hosted persistence and unblocks sales proof.

## Stage Diagnosis
- Stage: pre-PMF validation.
- This is an operational blocker, not a product blocker: the workflow is already built; it needs canonical merge + 2 config knobs.

## Maintainer One-Time Setup (15 min)

### 1) Merge workflows into canonical repo
Merge these files into the canonical repo default branch:
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` (optional but recommended)
- `.github/workflows/cycle-005-supabase-apply.yml` (optional)

Safety properties to sanity check in review:
- Scheduled run is gated by repo variable `CYCLE_005_AUTORUN_ENABLED=true` (prevents PR spam).
- Workflow probes candidate origins and refuses marketing/static sites (requires `/api/workflow/env-health`).
- PR branch is stable (`cycle-005-hosted-persistence-evidence`) to avoid infinite PR creation.

### 1b) Know what “preflight-only” does and does not do
`preflight_only=true` is intentionally read-only:
- It selects a valid deployed `BASE_URL`.
- It enforces hosted runtime env vars via `/api/workflow/env-health`.
- It runs `/api/workflow/supabase-health` when `skip_sql_apply=true` (default), to verify schema + seed is already in place.
- It does not apply SQL.
- It does not run intake, write evidence, or open a PR.

### 2) Set the correct deployed BASE_URL candidates
Set repo variable (recommended):
- Variable: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- Value: 2-4 origins (space/comma/newline separated), for the deployed Next.js app that serves `/api/workflow/*`

Option A (GitHub UI):
1. Repo -> Settings -> Secrets and variables -> Actions -> Variables
2. New repository variable
3. Name: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
4. Value example:
   - `https://your-app.example.com`
   - `https://your-project.vercel.app`

Option B (`gh` CLI):
```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R OWNER/REPO --body "https://a.example.com https://b.example.com"
```

Hard rule: candidates must return HTTP 200 JSON at:
```bash
curl -sS https://<origin>/api/workflow/env-health | jq .
```

### 3) Ensure hosted runtime has Supabase env vars and redeploy
This config lives on the hosting provider (Vercel/Cloudflare/etc), not in GitHub.

Required env vars on the hosted runtime:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Verify after redeploy:
```bash
curl -sS https://<origin>/api/workflow/env-health | jq -r '.ok, .env'
```
Expected:
- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

References:
- `docs/devops/cycle-005-hosted-runtime-env-vars.md`
- `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md` (optional automation)
- `docs/devops/cycle-005-cloudflare-pages-env-sync.md` (optional automation)

## Repo Variables and Secrets (What You Actually Need)

Preflight-only run (`preflight_only=true`, default):
- Required repo variables:
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (2-4 origins)
- Required hosting-provider env vars (on the deployed runtime, not GitHub):
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- GitHub secrets:
  - none required for the happy path

Full evidence run (`preflight_only=false`):
- Required:
  - same as preflight-only (BASE_URL candidates + hosted runtime env vars)
- Required only if you need CI to apply SQL (`skip_sql_apply=false`):
  - GitHub secret `SUPABASE_DB_URL` (direct Postgres connection string)
- Optional (recommended for resilience):
  - GitHub secrets `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (used only for fallback DB evidence fetch if the hosted runtime DB-evidence endpoint fails)
  - Set input `require_fallback_supabase_secrets=true` to fail-fast if you want to enforce those secrets exist.

Optional provider automation (only if you want the workflow to auto-fix missing hosted env vars):
- Vercel:
  - GitHub secret `VERCEL_TOKEN`
  - Repo variable `VERCEL_PROJECT_ID` or `VERCEL_PROJECT`
  - Optional repo variables `VERCEL_TEAM_ID` or `VERCEL_TEAM_SLUG`
  - Optional GitHub secret `VERCEL_DEPLOY_HOOK_URL` (to trigger redeploy)
- Cloudflare Pages:
  - GitHub secret `CLOUDFLARE_API_TOKEN`
  - Repo variables `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`
  - Optional GitHub secret `CF_PAGES_DEPLOY_HOOK_URL`

## First Run (Preflight) (5 min)

### Option A: run in GitHub Actions UI
1. Actions -> `cycle-005-hosted-persistence-evidence` -> Run workflow
2. Leave `base_url` empty (if you set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`)
3. Keep defaults unless you know you need SQL apply:
   - `skip_sql_apply`: `true` (default)
4. Keep `preflight_only=true` (default for manual dispatch)

Pass criteria:
- Artifact uploaded:
  - `cycle-005-hosted-preflight`
- No PR is expected in preflight-only mode.

If it fails on `supabase-health`:
- That means schema/seed is not in place yet.
- Apply the SQL bundle via Supabase Dashboard SQL Editor (or run `.github/workflows/cycle-005-supabase-apply.yml` if you have it wired), then rerun preflight.

### Option B: run from terminal (preferred if you have `gh` permissions)
```bash
make cycle-005-preflight
```

## Evidence Run (Creates/Updates PR)

After the preflight is green, run again with `preflight_only=false` to create/update the evidence PR.

UI:
1. Actions -> `cycle-005-hosted-persistence-evidence` -> Run workflow
2. Set `preflight_only=false`

CLI:
```bash
make cycle-005-evidence
```

Success criteria:
- Artifacts uploaded:
  - `cycle-005-hosted-preflight`
  - `cycle-005-hosted-persistence-evidence`
- PR created/updated from branch `cycle-005-hosted-persistence-evidence`

## Optional: Bootstrap + Enable Scheduled Refresh (Safe Path)
To bootstrap BASE_URL candidates via best-effort autodiscovery (GitHub Deployments metadata, then hosting APIs) and persist them:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO --autodiscover --set-variable --preflight-only
```
If you want the safe maintainer flow (set candidates once, run preflight-only, then enable schedule only after the preflight is green):
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --repo OWNER/REPO \
  --candidates "https://a.example.com https://b.example.com" \
  --set-variable \
  --enable-autorun-after-preflight
```
Or in the Actions UI, set:
- `preflight_only=true`
- `enable_autorun_after_preflight=true`

If you want this to run on schedule afterward:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --enable-autorun
```

## Common Failure Modes (Actionable)

### Wrong BASE_URL (marketing site)
Symptom: `/api/workflow/env-health` returns 404/HTML.
Fix: update `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to include the actual Next.js runtime origin.

### Supabase env missing on hosted runtime
Symptom: env-health succeeds but shows env flags false; workflow fails with “configure env vars and redeploy”.
Fix: set `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` on hosting provider, then redeploy.

### Schedule runs do nothing
Symptom: scheduled run summary says “skipped (schedule gated)”.
Fix: set repo variable `CYCLE_005_AUTORUN_ENABLED=true` after the first successful manual run.

## Operating Priorities (This Week)
1. Get one successful run and one PR merged (proof of hosted persistence).
2. After success, enable schedule gate to keep evidence fresh (`CYCLE_005_AUTORUN_ENABLED=true`).
3. Only then consider automating provider env sync (Vercel/Cloudflare) if it’s repeatedly failing.
