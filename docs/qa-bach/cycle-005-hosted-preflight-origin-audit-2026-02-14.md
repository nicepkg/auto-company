# Cycle 005 Hosted Persistence Preflight: Runtime Origin Audit (QA-Bach, 2026-02-14)

## Objective
Identify the real production origin(s) for the deployed workflow API runtime for `junhengz/auto-company`:

- `GET <BASE_URL>/api/workflow/env-health` returns `200` JSON with:
  - `.ok == true`
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Then ensure `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is set (or make discovery self-healing), and rerun Cycle 005 hosted persistence preflight until green.

## Current State (Blocker)
As of 2026-02-14, `junhengz/auto-company` has **no discoverable production deployment** of the Next.js workflow runtime (`/api/workflow/*`).

Evidence signals:
- GitHub Deployments metadata for the repo is empty (`/repos/junhengz/auto-company/deployments` returns `[]`).
- Repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` is not reliably usable until a real hosted runtime exists. If it is ever set to a marketing/static origin (e.g., `https://auto-company.pages.dev`), it will cause deterministic preflight failures.
- Public candidate origins probed to date either:
  - return Vercel `DEPLOYMENT_NOT_FOUND` (HTTP 404), or
  - serve a marketing/static site (e.g., Cloudflare Pages `auto-company.pages.dev` returns `text/html` and identifies as Astro).

Operational consequence:
- Cycle 005 hosted persistence preflight fails at **BASE_URL selection** because there is no real runtime origin to probe.

## What “Green Preflight” Actually Requires
In the default preflight-only mode for `.github/workflows/cycle-005-hosted-persistence-evidence.yml`:
- BASE_URL selection succeeds (valid runtime answers `/api/workflow/env-health`)
- env-health enforces the two Supabase env vars are present (booleans true)
- supabase-health is enforced when:
  - `skip_sql_apply=true` and
  - `preflight_require_supabase_health=true` (default)

## Durable Fix (Real Production Hosting)
1. Deploy the Next.js workflow runtime (`projects/security-questionnaire-autopilot`) to a hosting provider (Vercel or Cloudflare Pages) with a stable production domain.
2. Configure hosted runtime env vars in the hosting provider (not GitHub Actions):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Apply the Cycle 005 SQL bundle to the target Supabase project (or ensure it is already applied):
   - `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
4. Verify from your machine:
   - `curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'`
   - `curl -sS "<BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1" | jq -e '.ok==true'`
5. Persist 2-4 real origins into the repo variable:
   - `gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R junhengz/auto-company --body "https://origin1 https://origin2"`
6. Rerun preflight (expected green):
   - `make cycle-005-preflight`

Self-discovery improvement (repo change on `qa-bach/local-runtime-preflight`):
- If you dispatch the workflow with `persist_base_url_candidates=true` while leaving `base_url` empty, and discovery produces candidates, the workflow will now persist the discovered, formatted list into `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` after a green preflight.

## Credential-Free Fallback (Within 1 Cycle)
If you do not yet have hosting credentials/integration configured, you can still get a **green preflight for env-health wiring** by using an **ephemeral local runtime** inside GitHub Actions:

- Added workflow input: `local_runtime=true`
- Behavior:
  - starts a local Next.js dev server inside the GHA job
  - forces BASE_URL candidates to `http://127.0.0.1:18080`
  - skips `supabase-health` enforcement in this mode

Operator command (run against a branch that contains the workflow change):
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo junhengz/auto-company \
  --ref <branch-with-local-runtime-change> \
  --local-runtime
```

This is a deliberate “get signal, not certainty” mode: it validates the runtime contract and the preflight plumbing, but it does **not** prove the hosted Supabase-backed runtime is correctly deployed.

Observed result (green preflight):
- GitHub Actions run `22011679812` on ref `qa-bach/local-runtime-preflight` completed with conclusion `success`.
- Selected BASE_URL was `http://127.0.0.1:18080` and `env-health` reported both env booleans `true`.

## Next Action
Pick the actual hosting provider/project for the workflow runtime (Vercel or Cloudflare Pages), deploy `projects/security-questionnaire-autopilot`, then set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to 2-4 stable production origins and rerun `make cycle-005-preflight` with `preflight_require_supabase_health=true` (default).
