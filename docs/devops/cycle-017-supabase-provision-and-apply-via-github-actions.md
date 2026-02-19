# Cycle 017: Supabase Provision + Apply via GitHub Actions (No CLIs)

Goal: remove local-machine credential/CLI blockers by running Supabase provisioning + SQL apply + verification in GitHub Actions.

## Workflows

1. Provision + apply + verify (preferred):
- `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`

2. Apply only (when a project already exists):
- `.github/workflows/cycle-005-supabase-apply.yml`

## Required GitHub Secrets (Names Only)

For provisioning:
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

For apply-only workflow:
- `SUPABASE_DB_URL`

## Outputs / Artifacts

The provision workflow uploads:
- The sanitized provision summary JSON (see workflow logs/artifacts)
- `supabase-connection-nonsecret.txt` (contains `project_ref`, `NEXT_PUBLIC_SUPABASE_URL`, `db_host`)
- `supabase-verify.json` (schema + seed verification result; no secrets)

The apply-only workflow uploads:
- `supabase-verify.json`

## Next Step After Provisioning

To make hosted `supabase-health` pass, the hosted runtime must be configured (hosting provider env vars):
- `NEXT_PUBLIC_SUPABASE_URL="https://<project_ref>.supabase.co"`
- `SUPABASE_SERVICE_ROLE_KEY="<from Supabase Dashboard -> Project Settings -> API>"`

Then use `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` (optional automation) or redeploy manually and re-check:
- `GET <BASE_URL>/api/workflow/env-health`
- `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`
