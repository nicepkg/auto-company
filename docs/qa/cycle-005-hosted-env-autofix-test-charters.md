# Cycle 005: Hosted Env Auto-Fix Test Charters

Date: 2026-02-13
Role: qa-bach

Scope: automation that upserts hosted Supabase env vars and triggers redeploy (Vercel, optional Cloudflare Pages).

## Primary Risks

- Secret leakage into logs (GitHub Actions logs, artifact uploads).
- Auto-fix mutates the wrong hosting project/environment (wrong `BASE_URL` candidates or wrong project id/name).
- Auto-fix succeeds in provider API but redeploy does not happen, leaving runtime unchanged.
- Polling loops cause long/expensive CI runs without improving outcome.

## Exploratory Charters

1. Vercel: missing env vars, auto-fix enabled
- Setup: `attempt_vercel_env_sync=true`, missing env-health booleans, Vercel vars + secrets present.
- Oracles:
  - Workflow reaches `Preflight: env-health (enforce)` with `has_env=true`.
  - No secret values appear in logs or artifacts.
  - `preflight/env-health.after-redeploy.json` contains only booleans (no values).

2. Vercel: env vars already present, auto-fix enabled
- Setup: env-health already shows both vars present.
- Oracles:
  - Auto-fix step is skipped (no redeploy triggered).
  - Evidence run proceeds normally.

3. Vercel: auto-fix enabled, missing Supabase secrets in GitHub Actions
- Setup: `attempt_vercel_env_sync=true`, Vercel token present, but one of the Supabase secrets missing.
- Oracles:
  - Auto-fix step exits early with a clear message.
  - Workflow fails at enforce step with actionable guidance.

4. Vercel: custom domain BASE_URL (not `*.vercel.app`)
- Setup: `BASE_URL` is a custom domain mapped to Vercel.
- Oracles:
  - Auto-fix still runs (workflow no longer requires `vercel.app` substring).
  - Redeploy resolution either works via alias, or falls back to redeploy latest production (project id/name).

5. Cloudflare Pages: env upsert only, no deploy hook configured
- Setup: run `cloudflare-pages-sync-supabase-env.sh` without `CF_PAGES_DEPLOY_HOOK_URL`.
- Oracles:
  - Script upserts env vars but exits non-zero with “redeploy required”.
  - No secret values are printed.

## Quick “Secret Leak” Checks

- `rg -n \"SUPABASE_SERVICE_ROLE_KEY\" .github/workflows` (ensure never echoed)
- Ensure scripts avoid `set -x` and avoid printing provider API responses that may contain values.

