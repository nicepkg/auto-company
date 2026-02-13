# Cycle 005: Hosted BASE_URL Discovery (Deterministic)

Date: 2026-02-13
Role: qa-bach

## Problem

Cycle 005 hosted persistence evidence requires a `BASE_URL` that points to the deployed **Next.js runtime** serving `app/api/workflow/*`.

Operator error mode: using the static marketing site domain (or any non-app service) will fail in confusing ways (HTML responses, 404s, redirects).

This repo does not contain a definitive production `BASE_URL` in code/config (it is deployment-environment-specific), so we need a deterministic probe.

## Deterministic Discovery Method

Script:
- `projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh`

Probe used:
- `GET <base>/api/workflow/env-health`

Acceptance (default):
- HTTP `200`
- JSON with `.ok == true`
- Hosted runtime has Supabase env configured:
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Output:
- Prints the chosen `BASE_URL` to stdout (single line), so it can be captured by CI.

## Usage (Local)

Single candidate:

```bash
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  https://<your-hosted-app-domain>
```

Multiple candidates (first match wins; whitespace or commas both OK):

```bash
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  "https://app.example.com, https://www.example.com"
```

If you want to identify the Next.js runtime even when Supabase env vars are not set yet:

```bash
ALLOW_MISSING_SUPABASE_ENV=1 \
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  "https://candidate1 https://candidate2"
```

## Usage (GitHub Actions)

The Cycle 005 evidence workflow is hardened to run this probe before executing the wrapper. You can pass one or more candidates in the `base_url` input (comma or space separated). The workflow will:

1. Probe candidates deterministically.
2. Fail-fast with a clear error if candidates look like the marketing site / wrong service.
3. Use the discovered `BASE_URL` for evidence collection.

## Common Fixes

If `env-health` is `ok=true` but `env.NEXT_PUBLIC_SUPABASE_URL` or `env.SUPABASE_SERVICE_ROLE_KEY` is `false`, you're hitting the right runtime but it is not configured for persistence. Set those env vars on the hosting provider (Vercel/Cloudflare Pages) and redeploy.

See: `docs/qa/cycle-005-hosted-persistence-evidence-preflight.md`
