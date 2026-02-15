# Cycle 005 Hosted Supabase Apply + Redeploy + Evidence (DevOps Execution Log)

Date: 2026-02-13
Owner: devops-hightower
Repo: `nicepkg/auto-company`
Scope: `projects/security-questionnaire-autopilot`

## Target Deliverable (Definition of Done)

1. Supabase schema+seed applied (bundle includes `public.workflow_app_meta`):
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
2. Hosted Next.js runtime redeployed with env vars set:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Run wrapper against the deployed `BASE_URL`:
   - `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh`
4. Evidence generated and sales ledger appended:
   - `docs/devops/cycle-005-supabase-persistence-<run_id>.json`
   - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` appended under `## Cycle 005 DB Persistence Evidence Log`

## Current Status (This Workspace)

Blocked: no credentialed hosted environment inputs are present here.

- `NEXT_PUBLIC_SUPABASE_URL`: unset
- `SUPABASE_SERVICE_ROLE_KEY`: unset
- `SUPABASE_DB_URL`: unset

Also missing local CLIs:
- `vercel`: missing
- `wrangler`: missing
- `psql`: missing
- `supabase`: missing

GitHub CLI is available and authenticated (`gh_auth=ok`), but this repository has:
- no GitHub Deployments metadata (`/deployments` returned `[]`)
- no GitHub Pages site
- insufficient permissions to list Actions secrets (403)

Consequence: this environment cannot (by itself) identify the deployed `BASE_URL`, set hosted env vars, redeploy, or apply SQL to the target hosted Supabase project.

## Local Preflight Completed (Deterministic)

Verified the paste-ready Dashboard SQL bundle is consistent with the migration + seed files:

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot
node scripts/verify-dashboard-sql-bundle.mjs \
  --bundle supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

Result: `PASS`.

## Base URL Discovery Attempts (Non-Authoritative)

These common default hostnames were probed for the `env-health` endpoint and were not found:

- `https://security-questionnaire-autopilot-hosted.vercel.app/api/workflow/env-health` -> 404 (deployment not found)
- `https://auto-company.vercel.app/api/workflow/env-health` -> 404 (deployment not found)
- `https://security-questionnaire-autopilot-hosted.pages.dev/api/workflow/env-health` -> DNS not found

## Fastest Credentialed Apply Path (Recommended)

This minimizes local tooling needs and preserves an audit trail:

1) Apply SQL bundle via Supabase Dashboard SQL Editor:
- Paste and run:
  - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
- Optional (local preflight; no secrets required):

```bash
cd /home/zjohn/autocomp/auto-company/projects/security-questionnaire-autopilot
node scripts/verify-dashboard-sql-bundle.mjs \
  --bundle supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

2) Set hosted runtime env vars in your hosting provider UI/secret store, then redeploy/restart:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

3) Verify the redeploy picked up vars (no secrets returned):

```bash
BASE_URL="https://<your-hosted-app-domain>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Expected:
- `.ok=true`
- `.env.NEXT_PUBLIC_SUPABASE_URL=true`
- `.env.SUPABASE_SERVICE_ROLE_KEY=true`

4) Run Cycle 005 wrapper against the real hosted base URL:

```bash
cd /home/zjohn/autocomp/auto-company

export SKIP_SUPABASE_SQL_APPLY=1
BASE_URL="https://<your-hosted-app-domain>"
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"

./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh \
  "$BASE_URL" \
  "$RUN_ID"
```

Expected outputs on success:
- `docs/qa/cycle-005-env-health-<run_id>.json`
- `docs/qa/cycle-005-supabase-health-<run_id>.json`
- `docs/devops/cycle-005-supabase-persistence-<run_id>.json`
- `docs/devops/cycle-005-hosted-supabase-run-metadata-<run_id>.txt`
- `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` appended entry

## Alternate Credentialed Apply Path (Most Automatable)

If you can store `SUPABASE_DB_URL` as a GitHub Actions secret, you can apply the bundle via workflow dispatch:
- Workflow: `.github/workflows/cycle-005-supabase-apply.yml`
- It runs: `node projects/security-questionnaire-autopilot/scripts/apply-supabase-sql.mjs <bundle>`

This still does not redeploy the Next.js runtime nor run the wrapper; it only makes the DB apply auditable and repeatable.

## Rollback (DB)

If a rollback is required, drop tables in reverse dependency order:

```sql
drop table if exists public.workflow_events;
drop table if exists public.pilot_deals;
drop table if exists public.workflow_runs;
drop table if exists public.workflow_app_meta;
```

## Next Action (Handoff)

Provide the deployed `BASE_URL` and confirm which hosting provider is used (Vercel or Cloudflare Pages), then set `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` on that runtime and redeploy so this workspace can run:
- `./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"`
