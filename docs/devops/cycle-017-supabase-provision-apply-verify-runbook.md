# Cycle 017 DevOps: Supabase Provision + Bundle Apply + Verify (No Local Supabase Env Needed)

Date: 2026-02-14

Goal: provision (or reuse) a Supabase project via the Supabase Management API, deterministically build `SUPABASE_DB_URL` from `(project_ref + db password)`, apply the shipped SQL bundle, and verify success with a non-secret machine-check.

## Required GitHub Secrets (Names Only)

Provisioning:
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Optional:
- `SUPABASE_REGION` (only if you want to set a region input; Supabase may ignore it)
- `SUPABASE_REGION_SELECTION_JSON` (optional; if your org uses region selection objects)

## Primary Automation Path (Recommended)

Use GitHub Actions, so local machines do not need any `SUPABASE_*` env vars.

Convenience runner (sets secrets optionally, dispatches, downloads evidence):
- `scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh`
- Runbook: `docs/devops/cycle-018-supabase-gha-secrets-and-dispatch.md`

Workflow:
- `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`

Behavior (end-to-end):
1. Provision (or reuse) the project via Management API.
2. Build `SUPABASE_DB_URL` deterministically from `project_ref` + `SUPABASE_DB_PASSWORD` (no secret printing).
3. Apply bundle:
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
4. Verify schema + seed with a machine-checkable JSON output:
   - `projects/security-questionnaire-autopilot/scripts/verify-supabase-bundle-applied.mjs`

Artifacts uploaded by the workflow (sanitized):
- Provision summary JSON (path emitted by the workflow step output)
- `projects/security-questionnaire-autopilot/runs/supabase-verify.json`

## Local Path (If You Explicitly Have Credentials)

If you do have the required secrets locally, this sequence avoids copy/pasting a full DB URL:

```bash
export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="your-org"
export SUPABASE_PROJECT_NAME="your-project"
export SUPABASE_DB_PASSWORD="***"

# Provision or reuse (writes sanitized JSON to docs/devops/; prints project_ref=...).
out="$(./projects/security-questionnaire-autopilot/scripts/supabase-mgmt-provision-project.sh)"
ref="$(echo "$out" | awk -F= '/^project_ref=/{print $2}')"

# Apply bundle using (ref + password) only.
export SUPABASE_PROJECT_REF="$ref"
./projects/security-questionnaire-autopilot/scripts/apply-supabase-bundle.sh \
  projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql

# Verify (non-secret, machine-checkable).
cd projects/security-questionnaire-autopilot
node scripts/verify-supabase-bundle-applied.mjs | jq -e '.ok == true'
```

## Hosted Runtime Follow-Up (Required For Cycle 005 Preflight)

Set on the hosting provider that runs the Next.js API (`/api/workflow/*`), then redeploy:
- `NEXT_PUBLIC_SUPABASE_URL="https://<project_ref>.supabase.co"`
- `SUPABASE_SERVICE_ROLE_KEY="***"`

Verify (authoritative):

```bash
curl -sS "<BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq -e '.ok == true'
```
