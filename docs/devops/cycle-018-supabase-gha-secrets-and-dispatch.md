# Cycle 018: Supabase GHA Secrets + Dispatch (Cycle 005 Provision/Apply/Verify)

Date: 2026-02-14
Owner: devops-hightower

Goal: remove the last manual blocker by making it copy/paste-able to (1) set required GitHub Actions secrets and (2) dispatch the shipped workflow `.github/workflows/cycle-005-supabase-provision-apply-verify.yml`, then (3) download evidence artifacts including `supabase-verify.json`.

## Prereqs

- `gh` authenticated to GitHub (`gh auth status -h github.com` must succeed)
- Repo permission: `WRITE` (or higher) to reliably dispatch workflows and set secrets
- Local deps: `jq` (for evidence validation)

Repo note:
- If your local checkout points at a repo where you only have `READ` (common when the canonical repo is org-owned), pass `--repo OWNER/REPO` to target a repo where you have `WRITE`/`ADMIN`, or have a maintainer run the workflow.

## Required GitHub Secrets (Names Only)

Repo: Settings -> Secrets and variables -> Actions -> Secrets

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

Optional:
- `SUPABASE_REGION_SELECTION_JSON` (JSON; example: `{"type":"smartGroup","code":"americas"}`)

## One Script (Recommended)

Script: `scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh`

Option A: set secrets from env (non-interactive), dispatch, watch, download artifacts:

```bash
export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="your-org-slug"
export SUPABASE_DB_PASSWORD="***"
# export SUPABASE_REGION_SELECTION_JSON='{"type":"smartGroup","code":"americas"}'

./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh \
  --repo "OWNER/REPO" \
  --set-secrets \
  --supabase-project-name "security-questionnaire-autopilot-cycle-005" \
  --reuse-existing true \
  --sql-bundle "projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
```

Option B: prompt for missing values (interactive), then dispatch:

```bash
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh \
  --set-secrets \
  --prompt-missing
```

## Evidence Output

The script writes a run directory under:

- `docs/devops/cycle-018-supabase-gha/run-<databaseId>-<ts>/`

Expected files:

- `run-summary.json` (non-secret)
- `artifacts/provision.json` (sanitized)
- `artifacts/provision.kv` (non-secret)
- `artifacts/supabase-verify.json` (non-secret; script asserts `.ok == true`)
- `supabase-connection-nonsecret.txt` (derived; includes `project_ref` and `NEXT_PUBLIC_SUPABASE_URL`)

## Next Step After Provisioning

To make hosted `/api/workflow/supabase-health?...` pass, set hosted runtime env vars (hosting provider, not GitHub Actions):

- `NEXT_PUBLIC_SUPABASE_URL="https://<project_ref>.supabase.co"`
- `SUPABASE_SERVICE_ROLE_KEY="***"` (from Supabase Dashboard -> Project Settings -> API)

Then redeploy and confirm:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq .
curl -sS "<BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```
