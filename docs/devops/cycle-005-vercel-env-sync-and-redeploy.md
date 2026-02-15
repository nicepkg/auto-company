# Cycle 005: Vercel Env Sync + Redeploy Automation

This repo includes a best-effort automation path to fix the most common hosted blocker:

- Deployed Next.js runtime serving `/api/workflow/*` is missing:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`

The workflow `.github/workflows/cycle-005-hosted-persistence-evidence.yml` can:

1. Detect missing env vars via `GET <BASE_URL>/api/workflow/env-health`
2. Upsert the env vars on Vercel via REST API
3. Trigger a redeploy via Vercel REST API (best-effort)
4. Wait until `env-health` reports both vars present

## One-Time Setup (Repo Admin)

### GitHub Secrets

- `VERCEL_TOKEN`
  - Vercel Personal Access Token (PAT) with access to the target project.
- `VERCEL_DEPLOY_HOOK_URL` (optional)
  - Vercel Deploy Hook URL. Used only as a fallback if API redeploy is not possible in your account/project.
- `NEXT_PUBLIC_SUPABASE_URL`
  - Supabase project URL (public, but stored as a secret for simplicity).
- `SUPABASE_SERVICE_ROLE_KEY`
  - Supabase service role key (secret).

### GitHub Repo Variables

At least one of:

- `VERCEL_PROJECT_ID` (recommended)
- `VERCEL_PROJECT` (project name; fallback)

Optional (only for team-scoped Vercel projects):

- `VERCEL_TEAM_ID`
- `VERCEL_TEAM_SLUG`

## Running Cycle 005 With Auto-Fix

1. Ensure `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` includes the **production** domain for the Vercel project (not an ephemeral preview deployment URL).
2. Dispatch the workflow:
   - `attempt_vercel_env_sync: true`

If `env-health` reports missing vars and the secrets/vars above exist, the workflow will:

- run `projects/security-questionnaire-autopilot/scripts/vercel-sync-supabase-env.sh <BASE_URL>`
- poll `GET <BASE_URL>/api/workflow/env-health` for up to 10 minutes

## Local Operator Alternative (No GitHub Actions)

If you have the required secrets locally, you can run:

```bash
./projects/security-questionnaire-autopilot/scripts/vercel-sync-supabase-env.sh "https://<your-app-origin>"
```

## Notes / Failure Modes

- If `BASE_URL` points at a preview deployment that no longer exists (or does not track production), redeploy may succeed but the selected `BASE_URL` will not update.
  - Fix: update `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to use the production domain for the project.
- Vercel env var updates require redeploy for changes to take effect in the built runtime.

## Security

- The workflow and scripts never print secret values (only booleans from `env-health`).
- Rotate `VERCEL_TOKEN` periodically and after access changes.
