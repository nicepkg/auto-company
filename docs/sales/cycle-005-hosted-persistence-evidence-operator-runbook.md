# Cycle 005 Hosted Persistence Evidence (Operator Runbook)

Goal: run the GitHub Actions workflow that produces hosted Supabase persistence evidence and appends an entry into the sales execution ledger.

## Minimal Inputs (Recommended)

1. Set a GitHub repo variable (once):
   - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` = `2-4` candidate hosted app domains/URLs (comma/space/newline separated) (recommended)
   - Fallback repo variables (supported): `CYCLE_005_BASE_URL_CANDIDATES`, `HOSTED_BASE_URL_CANDIDATES`, `WORKFLOW_APP_BASE_URL_CANDIDATES`

Examples (domains or URLs both work):

```text
security-questionnaire-autopilot-hosted-git-main-<team>.vercel.app
auto-company-git-main-<team>.vercel.app
https://<custom-domain>
```

2. Run workflow_dispatch:
   - Workflow: `cycle-005-hosted-persistence-evidence`
   - Leave `base_url` blank (it will use the repo variable)
   - Leave `run_id` blank (workflow will generate one)
   - Keep `skip_sql_apply=true` unless you explicitly want Actions to apply the SQL bundle using `SUPABASE_DB_URL`
   - Note: `preflight_only` defaults to `true` for manual dispatch. Set `preflight_only=false` to generate the evidence PR.

CLI path (recommended, does best-effort local BASE_URL selection + dispatch + watch; the workflow itself runs the smoke checks and uploads artifacts):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --skip-sql-apply true
```

Preflight-only (recommended before the first evidence run):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --preflight-only \
  --skip-sql-apply true
```

## How BASE_URL Is Selected (Deterministic)

The workflow probes each candidate:

- `GET <candidate>/api/workflow/env-health`

It deterministically selects the first candidate that returns `ok=true` and has:

- `NEXT_PUBLIC_SUPABASE_URL=true`
- `SUPABASE_SERVICE_ROLE_KEY=true`

No secret values are returned by `env-health` (booleans only).

## Evidence Output (What the PR Should Contain)

The workflow creates a PR that includes:

- `docs/qa/cycle-005-*.json`
- `docs/devops/cycle-005-*.json`
- `docs/devops/cycle-005-*.txt`
- Appended entry in:
  - `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` under `## Cycle 005 DB Persistence Evidence Log`
