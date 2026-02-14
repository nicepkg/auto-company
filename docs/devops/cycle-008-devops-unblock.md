# Cycle 008 DevOps Unblock: Hosted `BASE_URL` Discovery + `codex exec` Rollout-State Mitigation

## Current Infra Status (Observed)

- Cycle 005 hosted persistence evidence is blocked because the production `BASE_URL` candidates are often unknown.
- GitHub Deployments metadata is frequently empty, so `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-github-deployments.sh` returns nothing (expected per its own docs).
- Provider discovery exists, but currently under-collects *preview/branch* URLs:
  - Vercel: only collects `deployments[].url` for `target=production` by default (commit/unique URLs), not *branch aliases*.
  - Cloudflare Pages: collects `pages.dev` + custom domains, but does not collect preview deployment URLs or branch aliases.
- `codex exec` sometimes emits log spam like `ERROR codex_core::rollout::list: state db missing rollout path ...` and can correlate with occasional hangs in loop runners.

## What “Correct BASE_URL” Means (Non-Negotiable)

The only probe that matters:

```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq .
```

Pass criteria:
- HTTP `200`
- JSON includes `"ok": true`
- For Cycle 005 evidence runs (hosted DB path), also requires:
  - `.env.NEXT_PUBLIC_SUPABASE_URL == true`
  - `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Scripts already enforce this:
- `projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh`
- `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`

## Hosting Discovery Improvements (Concrete, High-Signal)

### 1) Vercel: Harvest Deployment Aliases (Branch URLs) + Include Preview Target

Why this matters:
- Vercel’s “branch URL” is an alias (format documented by Vercel), and is often the easiest stable URL to hand to operators.
- The current collector only includes `deployments[].url` from `GET /v6/deployments`, which is typically the commit/unique host, not the branch alias.

Specific improvements:
1. Query deployments for both environments:
   - Default `VERCEL_DEPLOYMENTS_TARGETS="production,preview"` (not only production).
2. For each returned deployment `uid`, query aliases:
   - `GET /v2/deployments/{uid}/aliases` and add each `.aliases[].alias` as a candidate.
3. Increase limit safely (operator-controlled):
   - Default `VERCEL_DEPLOYMENTS_LIMIT=20` (current default is 10).
4. Optional: prefer “current commit” candidates in CI:
   - If `GITHUB_SHA` is present (GHA), prefer deployments whose `meta.githubCommitSha` matches.
   - Note: Vercel CLI docs confirm `githubCommitSha` is a common meta key used for filtering.

Expected impact:
- Finds branch URLs like `<project>-git-<branch>-<scope>.vercel.app` (alias), plus any custom preview suffix aliases if configured.

### 2) Cloudflare Pages: List Deployments + Include Preview Aliases

Why this matters:
- Cloudflare Pages preview deployments have:
  - A unique hash URL: `<hash>.<project>.pages.dev`
  - A branch alias: `<branch>.<project>.pages.dev` (lowercased; non-alphanumeric replaced with `-`)
- Current collector does not call the deployments endpoint, so it misses both.

Specific improvements:
1. Call the deployments list endpoint and collect:
   - `GET /client/v4/accounts/{account_id}/pages/projects/{project}/deployments`
   - Add each deployment’s primary URL (when present) and each entry in `aliases`.
2. Add a deterministic branch-alias heuristic (no API required) when branch is known:
   - If `CF_PAGES_BRANCH` is set (or `GITHUB_REF_NAME` in CI), add:
     - `https://<normalized-branch>.<project>.pages.dev`

Expected impact:
- Increases discovery coverage for preview/PR environments dramatically, while still relying on `env-health` to reject the wrong origins.

### 3) Keep GitHub Deployments as Best-Effort Only

GitHub Deployments metadata is optional and often not published by hosting providers. Keep it, but treat it as a last-resort source.

## Exact Vars/Secrets Required (Discovery + Optional Env-Sync)

### Vercel (Discovery)

Required:
- `VERCEL_TOKEN` (secret)
- `VERCEL_PROJECT_ID` (preferred) or `VERCEL_PROJECT` (variable)

Optional (team scope):
- `VERCEL_TEAM_ID` (variable)
- `VERCEL_TEAM_SLUG` (variable)

Optional (coverage controls):
- `VERCEL_DEPLOYMENTS_LIMIT` (default today: 10; recommend: 20)
- `VERCEL_DEPLOYMENTS_TARGET` (current script uses one value; recommend moving to `VERCEL_DEPLOYMENTS_TARGETS`)
- `VERCEL_DEPLOYMENTS_TARGETS` (proposed): `production,preview`

Optional (CI preference):
- `GITHUB_SHA` (present in GitHub Actions)

### Cloudflare Pages (Discovery)

Required:
- `CLOUDFLARE_API_TOKEN` (secret)
- `CLOUDFLARE_ACCOUNT_ID` (variable)
- `CF_PAGES_PROJECT` (variable)

Optional:
- `CF_PAGES_DEPLOYMENTS_LIMIT` (proposed): how many recent deployments to scan (recommend: 20)
- `CF_PAGES_BRANCH` (proposed): preferred branch alias to add as a candidate

### GitHub Deployments (Discovery)

Required:
- `GITHUB_REPOSITORY`
- `GITHUB_TOKEN`

Optional filters:
- `DEPLOYMENT_ENVIRONMENT`
- `DEPLOYMENT_REF`
- `PER_PAGE`
- `MAX_CANDIDATES`

### Hosted Runtime Env Vars (Not GitHub Actions)

These must be configured in the hosting provider runtime environment (Vercel/Cloudflare Pages) and require a redeploy to take effect:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (store as sensitive/secret where possible)

### Vercel (Env Sync + Redeploy Automation)

Used by:
- `projects/security-questionnaire-autopilot/scripts/vercel-sync-supabase-env.sh`
- `projects/security-questionnaire-autopilot/scripts/vercel-upsert-project-env-vars.sh`
- `projects/security-questionnaire-autopilot/scripts/vercel-redeploy-from-base-url.sh`

Required:
- `VERCEL_TOKEN`
- `VERCEL_PROJECT_ID` or `VERCEL_PROJECT`
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Optional:
- `VERCEL_TEAM_ID`, `VERCEL_TEAM_SLUG`
- `VERCEL_ENV_TARGETS` (default: `production,preview`)
- `VERCEL_DEPLOY_HOOK_URL` (fallback redeploy method)
- `TIMEOUT_SECONDS` (poll timeout; default: 600)

### Cloudflare Pages (Env Sync + Redeploy Automation)

Used by:
- `projects/security-questionnaire-autopilot/scripts/cloudflare-pages-sync-supabase-env.sh`
- `projects/security-questionnaire-autopilot/scripts/cloudflare-pages-upsert-project-env-vars.sh`

Required:
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CF_PAGES_PROJECT`
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Optional:
- `CF_PAGES_DEPLOY_HOOK_URL` (recommended; otherwise operator triggers deploy manually)
- `TIMEOUT_SECONDS` (poll timeout; default: 600)

## Operator Commands (Deterministic)

Local, explicit candidates:

```bash
./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
  https://candidate1.example.com \
  https://candidate2.example.com
```

Local, autodiscover via hosting APIs (best-effort), then probe:

```bash
./projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh
```

If you only want to identify the correct runtime (even before Supabase env vars are set):

```bash
ALLOW_MISSING_SUPABASE_ENV=1 \
./projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh
```

## Mitigation: `codex exec` Rollout-State DB Errors / Hangs

### What’s happening

Logs show repeated errors like:
- `ERROR codex_core::rollout::list: state db missing rollout path for thread <id>`

This appears to be caused by the `collab` feature being enabled in the local Codex config and/or stale rollout state referencing missing rollout JSONL files.

### Mitigation we can bake into run commands (low risk)

For non-interactive, “fire and forget” cycles where you already persist outputs elsewhere:
1. Add `--ephemeral` (don’t persist sessions/rollouts to disk)
2. Disable `collab` for the run to avoid rollout listing behavior:
   - `--disable collab` (or `-c features.collab=false`)

Example pattern:

```bash
codex exec - \
  --ephemeral \
  --disable collab \
  --json \
  --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  -c 'reasoning.effort="high"' \
  -c 'model_reasoning_effort="high"'
```

If you need persistent sessions (for `codex resume`), keep persistence on, but still disable `collab` in batch runners.

### Fallback guardrail (already present)

`auto-loop.sh` already has a watchdog timeout/kill. Keep it even after adding the above mitigations.

## Patch Proposals (Do Not Apply In This Run)

### Proposal A: Vercel Discovery Coverage

File: `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh`

Edits:
1. Replace single `VERCEL_DEPLOYMENTS_TARGET` with `VERCEL_DEPLOYMENTS_TARGETS` (default `production,preview`) and iterate targets.
2. For each deployment `uid`, call `GET /v2/deployments/{uid}/aliases` and add `.aliases[].alias`.
3. If `GITHUB_SHA` is set, prefer (or filter to) deployments where `.meta.githubCommitSha == $GITHUB_SHA` (best-effort).

### Proposal B: Cloudflare Pages Discovery Coverage

File: `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`

Edits:
1. Call deployments list endpoint:
   - `GET /accounts/{account_id}/pages/projects/{project}/deployments`
2. Add candidates from:
   - `.result[].url` (when present)
   - `.result[].aliases[]` (branch alias + hash URL)
3. Add deterministic branch-alias candidate when branch is known:
   - Input `CF_PAGES_BRANCH` (or use `GITHUB_REF_NAME`)
   - Candidate: `<normalized-branch>.<project>.pages.dev`

### Proposal C: Bake `codex exec` Mitigation Into Loop Runner

File: `auto-loop.sh`

Edit:
- In the `cmd=(codex exec ...)` array, add:
  - `--ephemeral`
  - `--disable collab`

Rationale:
- Eliminates the rollout-state coupling for batch runs, reducing log spam and lowering hang probability.

## Next Action

Implement Proposal A + B + C, then re-run `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh` with provider creds to populate `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, then trigger `.github/workflows/cycle-005-hosted-persistence-evidence.yml` with `base_url` left empty.

