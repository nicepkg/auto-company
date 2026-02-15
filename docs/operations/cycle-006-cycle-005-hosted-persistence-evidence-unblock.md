# Cycle 006 Ops: Unblock Cycle 005 Hosted Persistence Evidence

## Stage Diagnosis
- Stage: pre-PMF / first pilot proof.
- This is an ops unblocker: we already have the workflow; we need a safe canonical merge + a small config surface.

## Operating Priorities (Top 3)
1. Get a deterministic deployed runtime `BASE_URL` configured once via `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.
2. Ensure hosted runtime has Supabase env vars and is redeployed (env-health booleans must be `true`).
3. Run one green preflight-only, then one green evidence run that opens a PR on branch `cycle-005-hosted-persistence-evidence`.

## Maintainer-Ready Low-Risk Sequence (Canonical)
1. Merge `.github/workflows/cycle-005-hosted-persistence-evidence.yml` into the default branch.
2. Set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to 2-4 deployed runtime origins.
3. Run manual dispatch with `preflight_only=true` (default).
4. Once green, enable schedule gate:
   - set repo variable `CYCLE_005_AUTORUN_ENABLED=true`, or
   - rerun preflight with `enable_autorun_after_preflight=true`.
5. Run manual dispatch with `preflight_only=false` to produce/update the evidence PR on branch `cycle-005-hosted-persistence-evidence`.

## Repo Config Requirements (Preflight-Only vs Full Evidence)

Preflight-only (`preflight_only=true`):
- Required:
  - Repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
  - Hosted runtime env vars (on Vercel/Pages/etc): `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
- Optional:
  - Provider automation (only if you want CI to auto-fix missing hosted env vars):
    - Vercel: secret `VERCEL_TOKEN`, vars `VERCEL_PROJECT_ID` or `VERCEL_PROJECT` (optional `VERCEL_TEAM_ID`/`VERCEL_TEAM_SLUG`)
    - Cloudflare Pages: secret `CLOUDFLARE_API_TOKEN`, vars `CLOUDFLARE_ACCOUNT_ID`, `CF_PAGES_PROJECT`

Full evidence (`preflight_only=false`):
- Required:
  - Everything from preflight-only (BASE_URL + hosted runtime env vars)
- Conditionally required:
  - If you intend CI to apply SQL (`skip_sql_apply=false`): secret `SUPABASE_DB_URL`
- Recommended:
  - Secrets `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` for fallback DB evidence fetch if the hosted runtime DB-evidence endpoint fails.

## Risky Defaults / Footguns (What To Watch)
- `preflight_only=true` does not apply SQL. If `supabase-health` fails, apply the SQL bundle via Supabase Dashboard (or run `.github/workflows/cycle-005-supabase-apply.yml` if available), then rerun preflight.
- Guardrail added: `preflight_only=true` with `skip_sql_apply=false` is rejected (otherwise you can get a misleading green preflight without DB readiness verification).
- `attempt_vercel_env_sync=true` default can create side effects if Vercel tokens/ids are configured. Only keep automation enabled if you're confident the token is scoped to the correct project/team.
- Schedule trigger runs every 6 hours, but is gated behind repo variable `CYCLE_005_AUTORUN_ENABLED=true`. Do not enable this gate until after a green preflight to avoid noisy failures.

## References
- Checklist: `docs/operations/cycle-005-hosted-persistence-evidence-maintainer-checklist.md`
- Operator runbook: `docs/operations/cycle-005-hosted-persistence-evidence-operator-runbook.md`
- Hosted runtime env fix guide: `docs/operations/cycle-005-hosted-runtime-env-vars.md`

