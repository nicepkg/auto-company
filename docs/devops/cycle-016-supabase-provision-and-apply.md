# Cycle 016 DevOps: Supabase Provision + SQL Bundle Apply (Cycle 005 Unblock)

Date: 2026-02-14

Goal: make Cycle 005 preflight pass `supabase-health` by ensuring the *target Supabase project* exists and has the shipped schema + seed applied.

Canonical runbook:
- `docs/devops/cycle-017-supabase-provision-apply-verify-runbook.md`

## Artifacts (Shipped)

- SQL bundle (migration + seed):
  - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
- Management API provisioning helper (no supabase/psql CLIs required):
  - `projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh`
- Deterministic DB URL builder (ref + db password; avoids copy/paste):
  - `projects/security-questionnaire-autopilot/scripts/supabase-build-db-url.sh`
- Local SQL apply helper (Node + pg; no psql required):
  - `projects/security-questionnaire-autopilot/scripts/apply-supabase-bundle.sh`
- Machine-checkable DB verify helper (no secrets output):
  - `projects/security-questionnaire-autopilot/scripts/verify-supabase-bundle-applied.mjs`
  - `projects/security-questionnaire-autopilot/scripts/verify-supabase-db.mjs`
- GitHub Action (auditable SQL apply):
  - `.github/workflows/cycle-005-supabase-apply.yml`
- GitHub Action (provision via Mgmt API, build DB URL, apply, verify):
  - `.github/workflows/cycle-016-supabase-provision-apply-verify.yml`

## Minimum Steps (Operator)

1. Provision or select the Supabase project.
2. Apply the bundle (Dashboard SQL Editor, GitHub Action, or local Node apply).
3. Set hosted runtime env vars (on hosting provider) and redeploy:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
4. Verify (authoritative):
   - `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `{ ok:true }`.

## Next Action

Run `projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh` with real `SUPABASE_ACCESS_TOKEN` + org inputs (or provision in the Dashboard), then apply `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`.
