# Cycle 005: Hosted Runtime Env Vars (Fail-Fast Fix Guide)

This is the fastest way to unblock the Cycle 005 hosted DB persistence evidence run when it fails on:

- missing/incorrect `BASE_URL`, or
- hosted `/api/workflow/env-health` showing `NEXT_PUBLIC_SUPABASE_URL=false` / `SUPABASE_SERVICE_ROLE_KEY=false`.

## What Must Be True

The Cycle 005 runner selects a deployed Next.js *workflow API runtime* by probing:

- `GET <BASE_URL>/api/workflow/env-health`

For an evidence run, that endpoint must return JSON with:

- `ok=true`
- `env.NEXT_PUBLIC_SUPABASE_URL=true`
- `env.SUPABASE_SERVICE_ROLE_KEY=true`

This is a hosted-runtime configuration requirement (not a GitHub Actions secret requirement).

## Where To Set The Hosted Runtime Env Vars

Set these two env vars on the hosting provider that runs the Next.js app:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Then redeploy/restart the deployment so the runtime process picks them up.

### Vercel

- Project -> Settings -> Environment Variables
- Add both variables for `Production` at minimum (and `Preview` if you test previews)
- Trigger a new deployment (or redeploy the latest)
- Optional automation (if configured): dispatch `.github/workflows/cycle-005-hosted-runtime-env-sync.yml` or run Cycle 005 evidence with `attempt_vercel_env_sync=true`.

### Cloudflare Pages

- Pages project -> Settings -> Environment variables
- Add both variables for `Production`
- Trigger a new deployment

## Common Confusion: GitHub Secrets vs Hosted Runtime Env

GitHub Actions secrets do not configure your hosted Next.js runtime.

- The runner probes the hosted runtime via `<BASE_URL>/api/workflow/env-health`.
- GitHub secrets like `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are only used for an optional
  fallback evidence-fetch path inside CI, and should not be relied on for configuring the hosted runtime.

## Quick Verification (Local)

```bash
BASE_URL="https://your-deployed-runtime.example.com"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

If either env boolean is `false`, fix hosting provider env vars and redeploy.
