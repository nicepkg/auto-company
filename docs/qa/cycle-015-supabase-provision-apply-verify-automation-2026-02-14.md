# Cycle 015: Supabase Provision + Apply + Verify (QA Signal)

Date: 2026-02-14
Owner: qa-bach

## Goal

Provide a repeatable, auditable, machine-checkable path to:

1. Provision (or reuse) a Supabase project via the Supabase Management API (no Supabase CLI).
2. Deterministically derive `SUPABASE_DB_URL` from `(project_ref + db password)`.
3. Apply the shipped SQL bundle (migration + seed).
4. Verify success without leaking secrets.

## Key Risks (What This Automation Reduces)

- Wrong Supabase project: tables exist, but `workflow_app_meta.schema_bundle_id` mismatches the app's expected bundle id.
- Seed missing: schema exists, but the `workflow_runs` seed row is absent so hosted acceptance fails.
- Secret leakage: DB URLs / tokens accidentally printed in CI logs or committed artifacts.

## Canonical Automation Path (Works Without Local `SUPABASE_*` Env Vars)

Use GitHub Actions `workflow_dispatch`:

- Workflow: `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`
- Inputs:
  - `supabase_project_name` (name to create/reuse)
  - `reuse_existing` (`true` recommended to avoid duplicates)
  - `sql_bundle` (default bundle path)

Required GitHub secrets (names only):
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Optional GitHub secret:
- `SUPABASE_REGION_SELECTION_JSON` (only if your org requires explicit region selection)

## Deterministic DB URL Construction

The deterministic mapping used for direct DB access is:

- Host: `db.<project_ref>.supabase.co`
- Port: `5432`
- User: `postgres`
- Database: `postgres`

Helper script (URL-encodes password):
- `projects/security-questionnaire-autopilot/scripts/supabase-build-db-url.sh`

## Apply + Verify (Non-Secret, Machine-Checkable Signal)

Apply script:
- `projects/security-questionnaire-autopilot/scripts/apply-supabase-bundle.sh`

Verification script (writes a JSON signal, no secrets):
- `projects/security-questionnaire-autopilot/scripts/verify-supabase-bundle-applied.mjs`

Expected artifact from CI:
- `projects/security-questionnaire-autopilot/runs/supabase-verify.json`

Pass criteria:
- JSON has `.ok == true`
- Includes expected `bundle_id`, `seed_id`, and seed run presence.

## Post-DB Acceptance (Hosted Runtime)

After DB is provisioned and seeded, you still must set hosted runtime env vars on the actual hosting provider (not GitHub Actions), redeploy, then check:

- `GET <BASE_URL>/api/workflow/env-health`
- `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`

## Next Action

Trigger `.github/workflows/cycle-005-supabase-provision-apply-verify.yml` after setting the required GitHub secrets, then use the resulting `project_ref` to set hosted runtime env vars and confirm `supabase-health` returns `{ ok: true }`.

