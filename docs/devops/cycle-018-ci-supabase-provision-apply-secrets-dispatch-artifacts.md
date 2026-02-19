# Cycle 018 DevOps: Scripted CI Supabase Provision + Apply (Secrets, Dispatch, Artifacts)

Date: 2026-02-14

Objective: an operator with only a GitHub token can:
1. Verify required repo secrets exist.
2. Set missing secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_ORG_SLUG`, `SUPABASE_DB_PASSWORD`) via `gh` or REST.
3. Dispatch `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`.
4. Fetch run artifacts and extract `supabase-verify.json`.
5. Troubleshoot common failures with concrete commands and evidence files.

All scripts below write evidence into `docs/devops/evidence/`.

## Prereqs

- `gh` CLI installed.
- A GitHub token with sufficient permissions for your repo.
  - Classic PAT: typically `repo` (private repos) + `workflow`. To list/set Actions secrets you also need Actions write access.
  - Fine-grained PAT: repo access + Actions read/write.
- Export one of:
  - `GH_TOKEN` (recommended; used by `gh`)
  - `GITHUB_TOKEN` (used by the REST secret setter script)

Repo inference:
- Scripts default to inferring `OWNER/REPO` from `gh` auth context or `git remote origin`.
- If inference fails, pass `--repo OWNER/REPO`.

## Step 1: Verify Required Secrets Exist (Names Only)

```bash
./scripts/devops/gha-secrets-verify.sh
```

If secrets are missing, the script exits non-zero and writes an evidence JSON file under `docs/devops/evidence/`.

## Step 2: Set Missing Secrets

### Option A: Set Secrets With `gh` (Recommended)

Interactive (prompts for missing values, no echo):

```bash
./scripts/devops/gha-secrets-set.sh
```

Non-interactive (values must be present as env vars with the same names as the secrets):

```bash
export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="***"
export SUPABASE_DB_PASSWORD="***"
./scripts/devops/gha-secrets-set.sh --non-interactive
```

### Option B: Set Secrets With REST (Evidence-Friendly Fallback)

GitHub requires libsodium sealed-box encryption. This repo includes a helper:
- `scripts/devops/github-actions-secret-set-rest.py`

Install dependency (once):

```bash
python3 -m pip install --user pynacl
```

Set a secret via stdin (preferred over argv):

```bash
export GITHUB_TOKEN="***"
printf '%s' "$SUPABASE_ACCESS_TOKEN" | python3 scripts/devops/github-actions-secret-set-rest.py \
  --repo OWNER/REPO \
  --name SUPABASE_ACCESS_TOKEN \
  --value-stdin
```

Repeat for `SUPABASE_ORG_SLUG` and `SUPABASE_DB_PASSWORD`.

## Step 3: Dispatch The Workflow (Scripted)

```bash
RUN_ID="$(
  ./scripts/devops/gha-workflow-dispatch.sh \
    --workflow cycle-005-supabase-provision-apply-verify-dispatch.yml \
    --supabase-project-name "security-questionnaire-autopilot-cycle-005" \
    --reuse-existing true \
    --sql-bundle "projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
)"
echo "RUN_ID=$RUN_ID"
```

Watch until completion:

```bash
gh run watch "$RUN_ID" --exit-status
```

## Step 4: Download Artifacts And Extract `supabase-verify.json`

```bash
./scripts/devops/gha-run-fetch-artifacts.sh --run-id "$RUN_ID"
```

Expected extraction targets:
- `docs/devops/evidence/supabase-verify-run-<RUN_ID>.json`
- `docs/devops/evidence/supabase-connection-nonsecret-run-<RUN_ID>.txt`
- `docs/devops/evidence/supabase-provision-summary-run-<RUN_ID>.json`

## One-Shot Operator Path (Recommended)

This wrapper verifies secrets, optionally sets missing, dispatches, watches, and downloads artifacts:

```bash
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --set-missing-secrets
```

Non-interactive (requires env vars already exported):

```bash
export SUPABASE_ACCESS_TOKEN="***"
export SUPABASE_ORG_SLUG="***"
export SUPABASE_DB_PASSWORD="***"
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --set-missing-secrets --non-interactive
```

Artifact-only (if you already have a run id):

```bash
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --run-id "$RUN_ID"
```

## Troubleshooting (Common Failures)

### 403 / Cannot List Or Set Secrets

Symptoms:
- `gha-secrets-verify.sh` writes `can_list:false` and exits non-zero.

Fix:
- Use a token with Actions secrets permission for the repo.
- Confirm `gh` is using your token:

```bash
gh auth status -h github.com
```

### Dispatched, But No Run Id Resolved

Symptoms:
- `gha-workflow-dispatch.sh` reports it could not resolve run id within timeout.

Fix:

```bash
REPO="OWNER/REPO"
gh run list -R "$REPO" --workflow cycle-005-supabase-provision-apply-verify-dispatch.yml -L 10
```

Then download artifacts with the correct run id:

```bash
./scripts/devops/gha-run-fetch-artifacts.sh --repo "$REPO" --run-id "<RUN_ID>"
```

### Artifact Download Fails / Artifact Name Mismatch

Fix:

```bash
gh run view "$RUN_ID"
gh run download "$RUN_ID" -D /tmp/run-artifacts
```

If the artifact exists but the expected file is missing, check the workflow definition:
- `.github/workflows/cycle-005-supabase-provision-apply-verify-dispatch.yml`

### SQL Apply Or Verification Fails

Symptoms:
- Run fails during apply or `supabase-verify.json` indicates `ok=false`.

Fix:
- Open the run logs (`RUN_ID` URL in the dispatch evidence JSON).
- Re-run with `reuse_existing=true` (default) to avoid creating multiple projects.
- Confirm you applied the expected bundle:
  - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`

## Next Action

Run:

```bash
./scripts/devops/run-cycle-005-supabase-provision-apply-verify.sh --set-missing-secrets
```
