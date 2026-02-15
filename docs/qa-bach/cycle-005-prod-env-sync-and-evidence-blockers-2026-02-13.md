# Cycle 005: Prod Hosted Env Sync + Persistence Evidence (QA-Bach)

Date (UTC): 2026-02-13  
Repo: `nicepkg/auto-company`  
Workspace: `/home/zjohn/autocomp/auto-company`

## Mission (Requested)
1. Set production hosted runtime env vars for Supabase:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
2. Trigger redeploy on the actual hosting provider used by this repo.
3. Run Cycle 005 hosted persistence evidence workflow to produce DB evidence artifacts.

## What I Could Confirm / Execute
### Repo access constraints (hard blocker)
- My GitHub token is authenticated, but `nicepkg/auto-company` permissions are **pull-only** (no push).
- Result: I cannot add/merge GitHub Actions workflows into the upstream repo, and I cannot configure Actions repo variables/secrets.

Evidence (local command outputs captured during execution):
- `gh api repos/nicepkg/auto-company -q '{permissions: .permissions, private: .private}'` returned `push:false`.
- `gh api repos/nicepkg/auto-company/actions/workflows -q '.total_count'` returned `0` (no workflows currently present upstream).

### Hosting CLI availability (hard blocker)
- `vercel` CLI is not installed in this environment.
- `wrangler` CLI is not installed in this environment.

Result: I cannot directly set env vars or redeploy via provider CLI from this host.

## Concrete Deliverable Shipped (Unblock PR)
Because the upstream repo currently has **no GitHub Actions workflows**, the smallest credible unblock is to add:
- A workflow to sync hosted runtime env vars (Vercel/Cloudflare) and redeploy (best-effort).
- A workflow to run Cycle 005 hosted persistence evidence and upload artifacts + open an evidence PR.
- The supporting scripts/runbooks referenced by those workflows.

I created a PR from my fork into upstream:
- PR: `https://github.com/nicepkg/auto-company/pull/1`
- Branch (fork): `junhengz:qa/cycle-005-hosted-env-sync-and-evidence`

## What Still Needs Credentials (Cannot Be Done From Here)
After PR merge, a maintainer must set repo-level configuration (names match workflow expectations):
- GitHub Secrets (minimum):
  - `VERCEL_TOKEN` (if hosted on Vercel)
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- GitHub Variables (minimum):
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (recommended; 2-4 candidate origins)
  - `VERCEL_PROJECT_ID` (or `VERCEL_PROJECT`) if using Vercel auto-discovery/auto-fix

Optional (only if applying SQL bundle inside the workflow, i.e. `skip_sql_apply=false`):
- GitHub Secret: `SUPABASE_DB_URL`

## QA Risk Notes (Why This Matters)
- The highest-cost failure mode remains: “looks deployed, but persistence evidence fails” because the hosted runtime lacks Supabase env vars or points at the wrong schema/seed.
- Cycle 005 runner hard-gates on `GET <BASE_URL>/api/workflow/env-health` reporting:
  - `env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `env.SUPABASE_SERVICE_ROLE_KEY == true`

## Next Action (Handoff)
1. Merge `https://github.com/nicepkg/auto-company/pull/1`.
2. Configure the required GitHub Secrets/Variables listed above.
3. Dispatch workflow `cycle-005-hosted-persistence-evidence` (workflow_dispatch) and confirm it uploads:
   - `cycle-005-hosted-preflight` artifacts
   - `cycle-005-hosted-persistence-evidence` artifacts (including `docs/devops/cycle-005-*.json`)
   - and opens a PR appending `run_id=...` to `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.

