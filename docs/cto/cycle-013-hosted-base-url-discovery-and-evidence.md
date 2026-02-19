# Cycle 013: Unblock Hosted BASE_URL Discovery + Deterministic Evidence Runs

Date: 2026-02-14

Audience: maintainer/operator with access to the deployed hosting provider (Vercel and/or Cloudflare Pages) and GitHub Actions on `nicepkg/auto-company`.

## Problem Statement

Cycle 005 evidence automation fails in non-obvious ways when the hosted runtime `BASE_URL` is ambiguous (marketing domain vs workflow API runtime) or when the hosted runtime is reachable but missing required Supabase env vars.

The unblock strategy is to make the *one durable contract* explicit and machine-checkable:

- `GET <BASE_URL>/api/workflow/env-health` must return `200` JSON with:
  - `.ok == true`
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

This endpoint returns only booleans (no secret values) and is safe to probe.

## Deterministic BASE_URL Discovery (Local)

1) Collect 2-4 *origins* (scheme + host, no path) from your hosting provider.

2) Probe and select the correct runtime:

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  "https://candidate-1 https://candidate-2"

BASE_URL="$(
  ALLOW_MISSING_SUPABASE_ENV=1 \
  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
    "https://candidate-1" "https://candidate-2"
)"
echo "$BASE_URL"
```

Interpretation:
- HTML / non-JSON response: wrong domain (typically a marketing/static site).
- `ok=true` but env booleans are `false`: correct runtime, missing hosted env vars (fix hosting env + redeploy).

## Provider API Candidate Collection (Optional, Best-Effort)

If you have API tokens, you can collect candidates automatically:

```bash
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh
```

If you don’t know the provider project/account identifiers, use:

- `docs/devops/cycle-012-hosting-provider-id-discovery.md`

## Deterministic Preflight + Evidence Run (GitHub Actions)

Preferred operator path is the wrapper (it probes locally and fails fast before dispatching CI):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo nicepkg/auto-company \
  --preflight-only \
  --candidates "https://candidate-1 https://candidate-2" \
  --persist-candidates
```

Once preflight is green, run the evidence job:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo nicepkg/auto-company \
  --candidates "https://candidate-1 https://candidate-2" \
  --persist-candidates \
  --skip-sql-apply true
```

If Supabase schema/seed is not yet applied, re-run with SQL apply enabled (requires `SUPABASE_DB_URL` secret in GitHub):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo nicepkg/auto-company \
  --candidates "https://candidate-1 https://candidate-2" \
  --persist-candidates \
  --skip-sql-apply false \
  --sql-bundle projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
```

## Failure Modes (What Breaks, What To Fix)

- “env-health not JSON” or HTTP != 200:
  - Fix: wrong `BASE_URL` candidate. Only the deployed Next.js runtime serving `/api/workflow/*` is valid.

- “Hosted runtime is reachable but missing required Supabase env vars”:
  - Fix: set `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` on the hosting provider (production environment at minimum), then redeploy.
  - Re-check: `curl -sS "$BASE_URL/api/workflow/env-health" | jq .`

- `supabase-health` `.ok != true`:
  - Fix: apply the SQL bundle, then re-run preflight/evidence.

## What “Done” Looks Like (Acceptance)

- A green `workflow_dispatch` run with `preflight_only=true` that uploads `cycle-005-hosted-preflight` artifact including:
  - `preflight/base-url-source.txt`
  - `preflight/base-url-candidates.txt`
  - `preflight/base-url-probe.txt`
  - `preflight/env-health.json` with required booleans `true`
  - `preflight/supabase-health.json` with `.ok == true` (when `skip_sql_apply=true`)

- A subsequent `preflight_only=false` run that:
  - uploads `cycle-005-hosted-persistence-evidence` artifacts
  - opens/updates PR branch `cycle-005-hosted-persistence-evidence`

