# Cycle 005: Cloudflare Pages Env Sync (Supabase)

Use this when the hosted Next.js workflow runtime is deployed on **Cloudflare Pages** and `GET <BASE_URL>/api/workflow/env-health` shows:

- `env.NEXT_PUBLIC_SUPABASE_URL=false` and/or
- `env.SUPABASE_SERVICE_ROLE_KEY=false`

## What This Does

1. Upserts required env vars into the Pages project via Cloudflare API:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
2. (Optional) Triggers a new deployment via a Pages deploy hook URL
3. Polls `env-health` until both vars are present

The workflow `.github/workflows/cycle-005-hosted-persistence-evidence.yml` supports this via:
- `attempt_cloudflare_pages_env_sync=true` (only runs for `*.pages.dev` BASE_URLs)

## Required GitHub Secrets / Vars (If Running In CI)

- Secrets:
  - `CLOUDFLARE_API_TOKEN`
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `CF_PAGES_DEPLOY_HOOK_URL` (optional, for auto-redeploy)
- Variables:
  - `CLOUDFLARE_ACCOUNT_ID`
  - `CF_PAGES_PROJECT`

## Local Run (curl+jq)

```bash
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
export CF_PAGES_PROJECT="..."
export NEXT_PUBLIC_SUPABASE_URL="https://<your-supabase-project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

# Optional (recommended): a Pages deploy hook that triggers a new build/deploy
export CF_PAGES_DEPLOY_HOOK_URL="https://..."

./projects/security-questionnaire-autopilot/scripts/cloudflare-pages-sync-supabase-env.sh "https://<your-app-origin>"
```

## Notes

- Without a redeploy, Pages will not pick up new env vars. If you do not set `CF_PAGES_DEPLOY_HOOK_URL`,
  you must redeploy manually after the upsert step.
- Secrets are never printed; `env-health` returns booleans only.
