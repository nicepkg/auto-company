# Cycle 022 (Operations/PG): Workflow Runtime Origins + Cycle 005 Preflight Green (2026-02-14)

## Current State (2026-02-14)
- `junhengz/auto-company` has **no confirmed production hosted workflow runtime origin** for the Next.js app that serves `GET /api/workflow/env-health`.
- Prior “guess” origins (`*.vercel.app`, `*.pages.dev`) were deterministically rejected: Vercel `DEPLOYMENT_NOT_FOUND`, Pages DNS failures, or HTML responses instead of JSON. See run `22011378418` artifacts (`cycle-005-hosted-base-url-probe/base-url-probe.txt`).
- GitHub Deployments metadata is empty (`/deployments` returns `[]`), so autodiscovery from Deployments cannot work until a host integration/pipeline publishes `environment_url`/`target_url`.

## What “Correct Runtime” Means
The runtime we need is the deployed Next.js workflow API runtime (not a marketing site). It must satisfy:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e \
  '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

## Credential-Free Fallback (1 Cycle)
When you do not yet have Vercel/Pages/Supabase provisioned, run Cycle 005 **preflight-only** in a mode that proves the runtime contract (BASE_URL selection + `env-health`) without requiring a real hosted origin.

### Option A: Local Runtime Inside GHA (No Public URL)
Dispatch from the branch that contains the `local_runtime` preflight input:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo "junhengz/auto-company" \
  --ref "qa-bach/local-runtime-preflight" \
  --local-runtime
```

Expected: workflow is green with `preflight_only=true`, and `supabase-health` is skipped (since there is no real Supabase yet).

### Option B: Cloudflare Quick Tunnel (Real Public Origin, Still Credential-Free)
This creates a temporary `https://*.trycloudflare.com` origin that serves the workflow runtime, then dispatches the Cycle 005 preflight against it.

```bash
scripts/devops/run-cycle-005-hosted-preflight-quick-tunnel.sh \
  --repo "junhengz/auto-company" \
  --ref "qa-bach/local-runtime-preflight" \
  --install-deps
```

Notes:
- This URL is not stable. Do **not** persist it into `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.
- This is useful for proving the “real origin” contract (`/api/workflow/env-health` JSON, not HTML/404) and for validating GHA wiring.

## Making It Durable (Production)
Once the app is actually deployed (Vercel/Cloudflare Pages) and the hosting env vars are set, set 2-4 production origins in the canonical repo variable:

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES \
  -R "junhengz/auto-company" \
  --body "https://<prod-origin-1> https://<prod-origin-2>"
```

Then rerun preflight (strong gate):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo "junhengz/auto-company" \
  --preflight-only \
  --skip-sql-apply true
```

If you want the workflow to “self-discover” without `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, you must configure provider-backed discovery (Vercel/Pages APIs) or publish GitHub Deployments metadata with `environment_url`/`target_url` (otherwise Deployments discovery remains empty).

## Next Action
Deploy `projects/security-questionnaire-autopilot` to a real host (Vercel preferred), capture the production origin(s), set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, then rerun Cycle 005 `preflight_only=true` with `preflight_require_supabase_health=true` until green.

