# Cycle 005: Hosted Runtime Env Vars (Next.js + Supabase)

Cycle 005 hosted persistence evidence requires the deployed Next.js runtime for `projects/security-questionnaire-autopilot` to be configured with Supabase credentials.

This is separate from GitHub Actions secrets: Actions secrets do not automatically configure your deployed app.

## Required On The Hosted Runtime

Set these environment variables on the hosting provider for the deployed Next.js app:

- `NEXT_PUBLIC_SUPABASE_URL`
  - Example: `https://<project-ref>.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY`
  - Server-side secret (do not expose in client logs)

After setting/updating env vars, redeploy/restart the app so the new deployment picks them up.

## Verify (No Secrets Exposed)

The hosted runtime publishes a safe boolean-only env check:

```bash
BASE_URL="https://<your-deployed-app-origin>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Pass criteria:

- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

If either boolean is `false`, the deployed runtime does not have the env var available (or has not been redeployed since setting it).

## Where To Set Env Vars

Vercel:

1. Project -> Settings -> Environment Variables
2. Add `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
3. Ensure they are set for `Production` (and Preview if you use preview URLs)
4. Redeploy the project

Cloudflare Pages:

1. Pages project -> Settings -> Environment variables
2. Add `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` for `Production`
3. Trigger a new deployment (or redeploy the latest commit)

## BASE_URL Selection (Avoid Marketing Domains)

`BASE_URL` must point at the deployed Next.js workflow API (not a marketing/static domain).

The one probe that matters:

- `GET <BASE_URL>/api/workflow/env-health` must return `200` JSON.

Helpful scripts and runbooks:

- `projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh`
- `docs/devops/base-url-discovery.md`
- `docs/devops/cycle-005-gha-base-url-and-secrets-runbook.md`

