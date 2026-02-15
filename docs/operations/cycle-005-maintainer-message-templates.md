# Cycle 005 Maintainer Messages (Copy/Paste)

## 1) PR Review Ask (merge to canonical repo)
Subject: Merge Cycle 005 evidence runner (scheduled + gated)

Body:
I need a maintainer merge to unblock Cycle 005 hosted persistence evidence generation.

What this adds:
- GitHub Action `cycle-005-hosted-persistence-evidence` (manual dispatch + scheduled cron)
- Schedule is gated behind repo variable `CYCLE_005_AUTORUN_ENABLED=true` to avoid PR spam.
- It probes candidate origins and only targets the deployed Next.js runtime serving `/api/workflow/env-health`.
- On success, it uploads evidence artifacts and opens/updates a PR from branch `cycle-005-hosted-persistence-evidence`.

Maintainer actions after merge (10 min):
1. Set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to 2-4 deployed app origins.
2. Ensure hosted runtime has env vars `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` and redeploy.
3. Run the workflow once manually; after success, optionally set `CYCLE_005_AUTORUN_ENABLED=true` for scheduled refresh.

Checklist: `docs/operations/cycle-005-hosted-persistence-evidence-maintainer-checklist.md`

## 2) BASE_URL Candidates Ask (if maintainer doesn’t know the deployment URL)
Can you share the production deployed app origin for the workflow runtime (the one that serves `/api/workflow/env-health`)?

We need 2-4 candidates to set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.
Sanity check:
`curl -sS https://<origin>/api/workflow/env-health | jq .`
should return JSON with `"ok": true`.

## 3) Hosted Runtime Env Vars Ask (Vercel/Cloudflare)
The evidence workflow is failing because the hosted runtime is missing required Supabase env vars.

Please set these on the hosting provider (production environment) and redeploy:
- NEXT_PUBLIC_SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

Verify after redeploy:
`curl -sS https://<origin>/api/workflow/env-health | jq -r '.ok, .env'`

Reference: `docs/devops/cycle-005-hosted-runtime-env-vars.md`
