# Cycle 005 Hosted Persistence Evidence (Maintainer Handoff)

Date: 2026-02-13

Goal: make the scheduled GitHub Action `.github/workflows/cycle-005-hosted-persistence-evidence.yml` reliably produce:

- workflow artifacts (`cycle-005-hosted-preflight`, `cycle-005-hosted-persistence-evidence`)
- a PR on branch `cycle-005-hosted-persistence-evidence` appending evidence into:
  - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

This is the smallest checklist to unblock the autonomous scheduled run (and to run it once manually).

## 1) Merge Workflow Into Canonical Repo

Required file:

- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

Optional but helpful:

- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` (provider env var sync automation)

## 2) Set Repo Variables (Canonical Repo)

These are GitHub Actions *variables* (not secrets):

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES="<u1> <u2> <u3> <u4>"`
  - 2-4 origins for the deployed Next.js app that serves `/api/workflow/*`.
  - Example values:
    - `https://security-questionnaire-autopilot.vercel.app`
    - `https://<project>.pages.dev`
  - Do not use a marketing/static site domain (it will return HTML/404 for `/api/workflow/env-health`).

CLI examples (requires `gh auth login`):

```bash
REPO="OWNER/REPO"
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "https://app-1.example.com https://app-2.example.com"
```

Note: scheduled runs are gated to avoid PR spam. Only enable the schedule after a green preflight:

```bash
REPO="OWNER/REPO"
gh variable set CYCLE_005_AUTORUN_ENABLED -R "$REPO" --body true
```

## 3) Ensure Hosted Runtime Env Vars Exist (Hosting Provider)

These must exist on the *hosting provider* for the deployed Next.js app (the runtime that serves `/api/workflow/*`):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

After setting them, redeploy the hosted app.

Verify on each candidate origin:

```bash
BASE_URL="https://app-1.example.com"
curl -sS "${BASE_URL}/api/workflow/env-health" | jq .
curl -sS "${BASE_URL}/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq .
```

Notes:

- GitHub Actions secrets do not configure the hosted runtime. They are only used for optional CI paths.
- `/api/workflow/env-health` now returns safe deploy metadata (provider + commit SHA/branch when available) to help diagnose stale deployments.

## 4) Trigger One Manual Run (Recommended Once)

From a machine with `gh` authenticated and permission to dispatch workflows:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo OWNER/REPO \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --persist-candidates \
  --enable-autorun-after-preflight \
  --skip-sql-apply true
```

Then (after preflight is green), run evidence (creates PR):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo OWNER/REPO \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --skip-sql-apply true
```

If everything is configured correctly, the script will:

- locally probe `/api/workflow/env-health` to select the correct runtime
- dispatch the workflow
- watch the run to completion
- print the resulting PR URL (if created)

## References (Deeper Runbooks)

- `docs/devops/cycle-005-gha-base-url-and-secrets-runbook.md`
- `docs/devops/cycle-005-hosted-runtime-env-vars.md`
- `docs/qa/cycle-005-hosted-persistence-evidence-preflight.md`
