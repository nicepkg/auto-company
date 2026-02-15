# Cycle 005 Evidence Acceptance (What “Done” Means)

This is the minimum proof required to claim “hosted persistence evidence is unblocked.”

## Acceptance Criteria
1. Canonical repo has `.github/workflows/cycle-005-hosted-persistence-evidence.yml` on default branch.
2. Repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is set (2-4 deployed runtime origins).
3. Hosted runtime responds OK:
   - `GET <BASE_URL>/api/workflow/env-health` returns HTTP 200 JSON
   - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
   - `.env.SUPABASE_SERVICE_ROLE_KEY == true`
4. A workflow run succeeds and uploads artifact `cycle-005-hosted-persistence-evidence` containing:
   - `docs/devops/cycle-005-supabase-persistence-<run_id>.json` (or equivalent evidence JSON)
5. A PR is created/updated from branch `cycle-005-hosted-persistence-evidence` that includes:
   - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` appended with a new evidence entry for `run_id=<run_id>`

## “Stop Conditions” (Do Not Continue Without Fixing)
- BASE_URL probe selects a site that does not serve `/api/workflow/*` (wrong deployment).
- env-health shows missing Supabase env flags. Fix hosting env + redeploy first.

## Weekly Goal (Ops)
- One successful evidence PR merged by end of week.
- Then enable scheduled refresh by setting `CYCLE_005_AUTORUN_ENABLED=true`.
