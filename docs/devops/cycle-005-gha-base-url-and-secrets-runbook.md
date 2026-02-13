# Cycle 005 GHA Runbook: BASE_URL + Secrets (Hosted Persistence Evidence)

This runbook triggers `.github/workflows/cycle-005-hosted-persistence-evidence.yml` safely, with guardrails to avoid accidentally using a static/marketing site URL.

## What Counts As The Correct BASE_URL

The correct hosted Next.js runtime (workflow API) must pass:

- `GET <BASE_URL>/api/workflow/env-health` -> `200` JSON and includes `{ "ok": true }`

For Cycle 005 evidence runs, the hosted runtime must also have Supabase env vars configured (the endpoint returns booleans, not secret values):

- `env.NEXT_PUBLIC_SUPABASE_URL = true`
- `env.SUPABASE_SERVICE_ROLE_KEY = true`

## Minimal Operator Inputs (Recommended)

To make workflow-dispatch runs deterministic with minimal operator input, set a repo variable once:

- GitHub Actions variable: `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (recommended)
  - Value: `2-4` candidate URLs, comma/space/newline separated
  - Example: `https://<app>.vercel.app https://<custom-domain>`

Then you can dispatch the workflow with `base_url` left empty.

Fallback variables supported by the workflow:
- `CYCLE_005_BASE_URL_CANDIDATES` (legacy)
- `HOSTED_BASE_URL_CANDIDATES`
- `WORKFLOW_APP_BASE_URL_CANDIDATES`

## Secrets Required By The Workflow

Set these as GitHub Actions secrets (repo-level or environment-level):

- `SUPABASE_DB_URL` (required only if you run with `skip_sql_apply=false`)

Optional (fallback-only, avoid if possible):
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Rationale: the Cycle 005 wrapper prefers hosted `POST /api/workflow/db-evidence` so the run does not need Supabase secrets inside GitHub Actions. It only uses the fallback PostgREST fetch if hosted evidence fails.

## Set Secrets (CLI)

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# Only if you plan to run skip_sql_apply=false
read -rs SUPABASE_DB_URL && echo
printf '%s' "$SUPABASE_DB_URL" | gh secret set SUPABASE_DB_URL -R "$REPO"

# Optional fallback-only (set only if hosted DB evidence is unreliable in your environment):
printf '%s' "https://<project-ref>.supabase.co" | gh secret set NEXT_PUBLIC_SUPABASE_URL -R "$REPO"
read -rs SUPABASE_SERVICE_ROLE_KEY && echo
printf '%s' "$SUPABASE_SERVICE_ROLE_KEY" | gh secret set SUPABASE_SERVICE_ROLE_KEY -R "$REPO"
```

## Set BASE_URL Candidates Variable (CLI)

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# Provide 2-4 candidates; the workflow probes /api/workflow/env-health and picks the first valid one.
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body \
  "https://<candidate-app-domain> https://<candidate-marketing-domain>"
```

If you prefer curating candidates in a file, start from:

- `docs/devops/base-url-candidates.template.txt`

Then format it to a single string:

```bash
./projects/security-questionnaire-autopilot/scripts/format-base-url-candidates.sh \
  docs/devops/base-url-candidates.template.txt
```

## Preflight BASE_URL Locally (Recommended)

```bash
BASE_URL="$(
  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
    "https://<candidate-app-domain>" \
    "https://<candidate-marketing-domain>"
)"

curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Pass criteria: `ok=true` (and for Cycle 005 evidence, both `env.*` booleans are `true`).

## Trigger The GitHub Action

Use multiple candidates if you are unsure which domain is the real Next.js runtime; the workflow probes `/api/workflow/env-health` and rejects marketing/static sites.

Recommended: use the operator runner (does best-effort local BASE_URL selection + dispatch + watch; the workflow itself runs the smoke checks and uploads artifacts):

```bash
./scripts/cycle-005/run-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --skip-sql-apply true
```

Manual dispatch (if you prefer direct `gh workflow run`):

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

gh workflow run cycle-005-hosted-persistence-evidence.yml -R "$REPO" \
  -f base_url="" \
  -f base_url_candidates="" \
  -f run_id="" \
  -f skip_sql_apply=true \
  -f require_fallback_supabase_secrets=false \
  -f sql_bundle="projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"

GHA_RUN_DBID="$(
  gh run list -R "$REPO" --workflow cycle-005-hosted-persistence-evidence.yml -L 1 \
    --json databaseId -q '.[0].databaseId'
)"
gh run watch -R "$REPO" "$GHA_RUN_DBID" --exit-status
```

## Risk + Rollback

- Main risk: running against the wrong deployment or Supabase project. Guardrails: `/api/workflow/env-health` must return JSON `{ ok:true }` and (for evidence runs) show Supabase env is configured.
- If you must apply SQL via the workflow (`skip_sql_apply=false`), prefer doing it first in Supabase Dashboard SQL Editor instead (then keep `skip_sql_apply=true`), to avoid unintended schema changes.
- Rollback is fastest by stopping the run and fixing the hosting env vars / base URL input; avoid “fix-forward” migrations in the wrong Supabase project.

## Debugging A Failed Run

- The workflow uploads a `cycle-005-hosted-preflight` artifact containing:
  - `preflight/base-url-probe.txt` (table across candidates)
  - `preflight/env-health.json`
  - `preflight/supabase-health.json`
