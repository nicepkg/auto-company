# Cycle 005: Hosted Runtime Env Vars (Supabase)

Cycle 005 evidence runs require the **deployed Next.js workflow runtime** (the app serving `/api/workflow/*`) to have Supabase env vars configured.

## Required Env Vars (Hosted Runtime)

- `NEXT_PUBLIC_SUPABASE_URL`
  - Public value (Supabase project URL).
  - Must exist for Next.js client code and server code.
- `SUPABASE_SERVICE_ROLE_KEY`
  - Secret value.
  - Must exist for server-side workflow endpoints that write/read evidence.

After changing env vars on your hosting provider, you must **redeploy** (or trigger a new build) for changes to take effect.

If you host on Vercel, this repo includes a best-effort automation path that can upsert env vars via the Vercel API and trigger a redeploy from GitHub Actions:

- `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md`

If you host on Cloudflare Pages, this repo includes an env upsert script (and optional deploy-hook driven redeploy):

- `docs/devops/cycle-005-cloudflare-pages-env-sync.md`

## Verify (One Probe)

This endpoint returns only booleans (never secret values):

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq .
```

Pass criteria:

- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

## Where To Set Them

### Vercel (Next.js)

1. Vercel Dashboard -> your Project -> Settings -> Environment Variables
1. Add:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
1. Ensure they are set for the environment you deploy (Production and/or Preview).
1. Trigger a new deployment (redeploy).

### Vercel Automation (Optional)

If you prefer not to click in the dashboard, the Cycle 005 GitHub Actions workflow can best-effort:

- upsert these env vars on Vercel via REST API
- trigger a redeploy via Vercel REST API (best-effort)

See:

- `docs/devops/cycle-005-vercel-env-sync-and-redeploy.md`
- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` (standalone sync)

### Cloudflare Pages (Next.js)

1. Cloudflare Dashboard -> Workers & Pages -> Pages -> your Project -> Settings
1. Add environment variables for the deployment environment you use (Production/Preview):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
1. Trigger a new deployment (redeploy).

### Cloudflare Pages Automation (Optional)

This repo includes a best-effort API-based env upsert for Cloudflare Pages (and optional build-hook trigger) via:

- `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` (provider=`cloudflare_pages`)

## GitHub Actions (Fallback-Only)

GitHub Actions secrets do **not** configure the hosted runtime. They are only used for the fallback evidence fetch path when `require_fallback_supabase_secrets=true`.

If you explicitly enable that fallback mode, set these GitHub Actions secrets:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
