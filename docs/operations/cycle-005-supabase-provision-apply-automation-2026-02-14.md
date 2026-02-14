# Cycle 005: Supabase Provision + Apply + Verify Automation (Shipped)

Date: 2026-02-14
Owner: operations-pg

Goal: provision a Supabase project via Management API (no Supabase CLI), apply the Cycle 003 migration+seed bundle, and emit a non-secret, machine-checkable verification signal.

## What Shipped

- Provision (Supabase Management API; no CLIs):
  - `projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh`
- Deterministic DB URL build from `(project_ref + db password)`:
  - `projects/security-questionnaire-autopilot/scripts/supabase-build-db-url.sh`
- Apply bundle (Node + pg; no psql needed), supports:
  - `SUPABASE_DB_URL`, or
  - `SUPABASE_PROJECT_REF` + `SUPABASE_DB_PASSWORD`
  - `projects/security-questionnaire-autopilot/scripts/apply-supabase-bundle.sh`
- Verify (non-secret JSON; machine-checkable exit code):
  - `projects/security-questionnaire-autopilot/scripts/verify-supabase-bundle-applied.mjs`
- GitHub Action (no local Supabase env vars required):
  - `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`

## GitHub Action: Inputs + Secrets (Names Only)

Workflow dispatch inputs:
- `supabase_project_name`
- `reuse_existing`
- `sql_bundle`

Required GitHub secrets:
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Optional GitHub secret:
- `SUPABASE_REGION_SELECTION_JSON`

## Success Signal (Non-Secret)

The workflow uploads:
- `provision.json` and `provision.kv` (sanitized; includes `project_ref`)
- `supabase-verify.json` (from `verify-supabase-bundle-applied.mjs`; contains `ok: true`, expected/actual bundle id, seed presence, and table presence)

## Local Operator Path (No Pre-Set Env Vars)

1. Provision (interactive):

```bash
export SUPABASE_PROMPT_FOR_MISSING=1
./projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh
```

2. Apply bundle (deterministic inputs; avoids pasting DB URL):

```bash
cd projects/security-questionnaire-autopilot
SUPABASE_PROJECT_REF="<project_ref>" SUPABASE_DB_PASSWORD="***" ./scripts/apply-supabase-bundle.sh
```

## Next Action

Run `.github/workflows/cycle-005-supabase-provision-apply-verify.yml` with the required GitHub secrets configured; take the resulting `project_ref` and set hosted runtime env vars (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`), redeploy, then confirm `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `{ ok:true }`.

