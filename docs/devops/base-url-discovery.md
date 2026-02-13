# Hosted `BASE_URL` Discovery (Workflow API)

Cycle 005 requires the **hosted workflow API** base URL for `projects/security-questionnaire-autopilot` (not the static marketing site).

## The One Probe That Matters

The correct hosted `BASE_URL` must return `200` JSON from:

- `GET /api/workflow/env-health`

This endpoint is safe: it returns only booleans (no secret values).

If `env` booleans are `false`, the deployed runtime is missing required hosting-provider env vars. See:

- `docs/devops/cycle-005-hosted-runtime-env-vars.md`

## Deterministic Discovery Script

Use:

```bash
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  <candidate-1> \
  <candidate-2>
```

Candidates may be full URLs (`https://...`) or bare hostnames; bare hostnames are treated as `https://<hostname>`.

For convenience, you can also keep candidates in a simple file (one URL per line) and format them into a single space-separated string:

```bash
./projects/security-questionnaire-autopilot/scripts/format-base-url-candidates.sh \
  docs/devops/base-url-candidates.template.txt
```

In CI contexts (GitHub Actions), you can also pass candidates via env:

```bash
BASE_URL_CANDIDATES="<candidate-1>, <candidate-2>" \
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh
```

For workflow-dispatch runs, prefer setting a GitHub Actions repo variable once:

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` = `2-4` candidate URLs (comma/space/newline separated) (recommended)
- Legacy/fallback variable names (supported by the workflow):
  - `CYCLE_005_BASE_URL_CANDIDATES`
  - `HOSTED_BASE_URL_CANDIDATES`
  - `WORKFLOW_APP_BASE_URL_CANDIDATES`

The Cycle 005 evidence workflow will use these variables automatically when workflow inputs are left empty.

If your hosting integration publishes GitHub Deployments metadata, you can also collect candidate URLs automatically (best-effort):

```bash
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-github-deployments.sh
```

## Optional: Hosting API Discovery (Vercel / Cloudflare Pages)

If you have API access, you can collect candidate URLs from hosting provider APIs (best-effort; prints newline-separated URLs):

```bash
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh
```

Supported providers and env vars:

- Vercel:
  - `VERCEL_TOKEN`
  - `VERCEL_PROJECT_ID` or `VERCEL_PROJECT`
  - Optional (team-scoped): `VERCEL_TEAM_ID` and/or `VERCEL_TEAM_SLUG`
- Cloudflare Pages:
  - `CLOUDFLARE_API_TOKEN`
  - `CLOUDFLARE_ACCOUNT_ID`
  - `CF_PAGES_PROJECT`

And if you want a single command that pulls candidates from env/vars/deployments and then probes `/api/workflow/env-health`, use:

```bash
./projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh
```

If you want a quick report across candidates (before selecting one), use:

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  <candidate-1> \
  <candidate-2>
```

By default, the script only accepts a candidate if the hosted runtime is configured for DB persistence (required for Cycle 005 evidence):

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

These must be set on the deployed runtime (hosting provider), then redeployed/restarted:

- `docs/devops/cycle-005-hosted-runtime-env-vars.md`

If you only want to confirm the app is correct (even before env vars are set):

```bash
ALLOW_MISSING_SUPABASE_ENV=1 \
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  https://<candidate-1> \
  https://<candidate-2>
```

## Where To Get Candidate URLs

Pick candidates from your deployment platform:

- Vercel: project deployments list + assigned domains (custom domain and `*.vercel.app` URLs)
- Cloudflare Pages/Workers: project URL and any attached custom domains

If you have CLI access, any command that enumerates domains/deployments is fine; the script will confirm correctness.

## Expected Output

The script prints progress to stderr and prints the chosen `BASE_URL` to stdout, so you can do:

```bash
BASE_URL="$(
  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh https://<candidate>
)"
echo "$BASE_URL"
```
