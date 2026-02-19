# Cycle 007: Hosted BASE_URL Blocker (Cycle 005 Evidence)

Date: 2026-02-14
Repo: `nicepkg/auto-company`
Scope: `projects/security-questionnaire-autopilot` hosted Next.js workflow runtime (`/api/workflow/*`)

## Summary

Cycle 005 hosted persistence evidence is blocked on one missing input that cannot be derived from this repo:

- the authoritative deployed workflow runtime origin(s) (`BASE_URL` candidates)

## What We Verified From This Workspace (2026-02-14)

1. GitHub Deployments metadata is empty (no environment URLs to scrape):

```bash
gh api /repos/nicepkg/auto-company/deployments?per_page=5
# -> []
```

2. Common guessed Vercel domains are not deployed (HTTP 404 `DEPLOYMENT_NOT_FOUND`):

- `https://security-questionnaire-autopilot-hosted.vercel.app/api/workflow/env-health`
- `https://security-questionnaire-autopilot.vercel.app/api/workflow/env-health`
- `https://auto-company.vercel.app/api/workflow/env-health`
- `https://auto-company-hosted.vercel.app/api/workflow/env-health`
- plus a larger matrix under `docs/qa-bach/cycle-005-base-url-probe-2026-02-13-v2.txt`

3. `https://auto-company.pages.dev/api/workflow/env-health` returns `200 text/html` (not JSON), so it is not the workflow runtime.

## What Maintainer Must Provide (Unblocks Everything)

Provide **2-4 candidate origins** (no paths, no trailing slash) for the deployed Next.js app that serves:

- `GET <BASE_URL>/api/workflow/env-health` -> `200` JSON

Examples (format only; not authoritative):

- `https://<custom-domain>`
- `https://<vercel-project>.vercel.app`
- `https://<pages-project>.pages.dev`

Then set them once as a repo variable:

- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES="<u1> <u2> <u3> <u4>"`

## Fast Verification (No Guesswork)

```bash
BASE_URL="https://<candidate-origin>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Pass criteria (Cycle 005 evidence gate):

- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

If either env boolean is `false`, set these **on the hosting provider** (Vercel/Pages/etc), then redeploy:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

## Next Action (Canonical Repo)

After merging PR #2, in `nicepkg/auto-company`:

1. Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to the real deployed origins.
2. Run workflow `cycle-005-hosted-persistence-evidence` with `preflight_only=true` (default).
3. Once green, rerun with `preflight_only=false` to generate the evidence PR.

