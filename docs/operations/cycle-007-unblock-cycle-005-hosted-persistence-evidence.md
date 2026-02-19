# Cycle 007 Ops (2026-02-14): Unblock Cycle 005 Hosted Persistence Evidence

## Stage Diagnosis
- Stage: pre-PMF pilot proof.
- Blocker type: operational configuration, not product. The workflow is built; we are missing a real deployed workflow-runtime `BASE_URL` and (likely) provider env + redeploy.

## Deliverable 1: Maintainer-Ready Steps To Obtain Authoritative `BASE_URL` Candidates

### The only thing that counts as a valid candidate
A valid `BASE_URL` candidate is an **origin** (no path) such that:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e '.ok == true'
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true'
```

If it’s HTML, `404`, or non-JSON: it is the wrong domain (marketing/static, stale preview, or no deployment).

### Option A (Recommended): Hosting Provider UI (authoritative, fastest)

1. Identify the hosting provider + *project* for the deployed Next.js workflow runtime:
   - Runtime code lives at: `projects/security-questionnaire-autopilot/app/api/workflow/*`
   - The domain must serve `GET /api/workflow/env-health` as JSON.
2. In the provider UI, copy 2-4 **production** origins for that project:
   - Vercel: Project -> Settings -> Domains (custom domain + `*.vercel.app`)
   - Cloudflare Pages: Project -> Custom domains + `*.pages.dev`
3. Validate each origin locally:
   - `curl -sS "<origin>/api/workflow/env-health" | jq .`
   - Keep only the origins where `.ok==true`.
4. Persist them in GitHub repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (space/comma/newline separated):
   - GitHub UI: Settings -> Secrets and variables -> Actions -> Variables
   - Or `gh`:
     ```bash
     gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R nicepkg/auto-company \
       --body "https://a.example.com https://b.vercel.app"
     ```

### Option B: Use the repo’s provider API collectors (if you already have tokens)

Vercel (prints candidate origins; then you still probe/curate):
```bash
cd /path/to/auto-company
export VERCEL_TOKEN="***"
export VERCEL_PROJECT_ID="***"   # or: export VERCEL_PROJECT="project-slug"
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh
```

Cloudflare Pages:
```bash
cd /path/to/auto-company
export CLOUDFLARE_API_TOKEN="***"
export CLOUDFLARE_ACCOUNT_ID="***"
export CF_PAGES_PROJECT="***"
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh
```

Then probe the printed origins and keep only those that pass `env-health`:
```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  <origin-1> <origin-2> <origin-3>
```

### Option C: GitHub Deployments metadata (only works if your deploy pipeline publishes it)
This repo’s workflow will attempt:
- `./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-github-deployments.sh`

If your deploy pipeline does not publish Deployments, this returns nothing; do not rely on it.

## Deliverable 2: “What We Tried” (Concrete Findings)

### GitHub Deployments discovery is empty
Per `docs/cto/cycle-005-prod-hosted-env-and-persistence-evidence-2026-02-13.md`, GitHub Deployments metadata returned no usable `environment_url` / `target_url`, so the repo cannot discover production `BASE_URL` deterministically.

### Common Vercel/Pages candidate names fail

QA probe on **2026-02-13** (`docs/qa-bach/cycle-005-base-url-probe-2026-02-13.txt`):
- `https://security-questionnaire-autopilot-hosted.vercel.app` -> `404 DEPLOYMENT_NOT_FOUND`
- `https://security-questionnaire-autopilot.vercel.app` -> `404 DEPLOYMENT_NOT_FOUND`
- `https://auto-company.vercel.app` -> `404 DEPLOYMENT_NOT_FOUND`
- `https://auto-company-hosted.vercel.app` -> `404 DEPLOYMENT_NOT_FOUND`
- `https://security-questionnaire-autopilot-hosted.pages.dev` -> could not connect / no response
- `https://security-questionnaire-autopilot.pages.dev` -> could not connect / no response

Additional v2 probe on **2026-02-13** tried `*-git-main-{nicepkg,junhengz}.vercel.app` style domains and all returned `404 DEPLOYMENT_NOT_FOUND` (`docs/qa-bach/cycle-005-base-url-probe-2026-02-13-v2.txt`).

Re-probe from this workspace on **2026-02-14**:
- Vercel `*.vercel.app` candidates above still return `404 DEPLOYMENT_NOT_FOUND`.
- `*.pages.dev` candidates above do not resolve via DNS (`curl: (6) Could not resolve host`).

Conclusion: there is no reachable deployment at the guessed domains. A maintainer must provide the real deployed workflow-runtime domain(s) from the hosting provider UI (or wire provider API discovery via tokens/ids).

## Deliverable 3: PR Comment Draft (nicepkg/auto-company#2)

Stored for copy/paste: `docs/operations/cycle-007-pr-comment-nicepkg-auto-company-2.md`

## Next Action (Handoff)
Maintainer (WRITE+) supplies 2-4 real workflow-runtime origins (Vercel/Pages/etc) that pass `GET /api/workflow/env-health`, sets `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, and runs `cycle-005-hosted-persistence-evidence` with `preflight_only=true` (default) followed by `preflight_only=false`.

