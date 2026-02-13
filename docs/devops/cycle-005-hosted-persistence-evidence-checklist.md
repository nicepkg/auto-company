# Cycle 005: Hosted Persistence Evidence Checklist (DevOps)

Goal: run `.github/workflows/cycle-005-hosted-persistence-evidence.yml` with minimal operator error and produce a PR that appends evidence to `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.

## 1) Confirm You Have The Right BASE_URL Candidates

You need 2-4 candidate origins for the deployed Next.js workflow runtime (not a marketing/static site), for example:

- `https://<project>.vercel.app`
- `https://<project>.pages.dev`
- `https://<custom-domain>`

Optional local probe:

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  <candidate-1> <candidate-2> <candidate-3>
```

Optional auto-discovery (requires hosting API env vars locally):

```bash
# Vercel:
export VERCEL_TOKEN="***"
export VERCEL_PROJECT="security-questionnaire-autopilot"

./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh
```

## 2) Set Repo Variable Once (Recommended)

Curate candidates in:

- `docs/devops/base-url-candidates.template.txt`

Then set the variable:

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
CANDIDATES="$(
  ./projects/security-questionnaire-autopilot/scripts/format-base-url-candidates.sh \
    docs/devops/base-url-candidates.template.txt
)"
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "$CANDIDATES"
```

If you want the runner to auto-discover candidates and set the variable for you:

```bash
./scripts/cycle-005/run-hosted-persistence-evidence.sh \
  --autodiscover-hosting \
  --set-variable \
  --skip-sql-apply true
```

## 3) Ensure Secrets Match The Run Mode

- Default run mode: `skip_sql_apply=true`
  - No required secrets for SQL apply.
- If you set `skip_sql_apply=false`:
  - Required GitHub secret: `SUPABASE_DB_URL`

Optional fallback-only secrets (only needed if hosted `POST /api/workflow/db-evidence` is unreliable):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Optional Vercel automation (only needed if you want CI to auto-fix missing hosted env vars):

- `VERCEL_TOKEN`
- `VERCEL_DEPLOY_HOOK_URL` (optional fallback if API redeploy is not possible)
- Repo variable: `VERCEL_PROJECT_ID` (or `VERCEL_PROJECT`)

See:
- `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md`

## 4) Trigger And Watch The Workflow (Recommended)

```bash
./scripts/cycle-005/run-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --skip-sql-apply true
```

## 5) Pass Criteria

The run should:

- Select the correct `BASE_URL` (see job summary)
- Generate evidence artifacts in the PR:
  - `docs/qa/cycle-005-*.json`
  - `docs/devops/cycle-005-*.json`
  - `docs/devops/cycle-005-*.txt`
- Append a new `run_id=...` entry in:
  - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

If the run fails:

- Download the `cycle-005-hosted-preflight` artifact
- Check `preflight/base-url-probe.txt`, `preflight/env-health.json`, and `preflight/supabase-health.json`
