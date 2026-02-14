# Cycle 003: SQ Autopilot Hosted Baseline (2026-02-14)

## Current Infra Status

- Canonical upstream code repo: `nicepkg/auto-company` (not a fork).
- Canonical repo that currently owns GitHub Actions variables (as operated by this agent): `junhengz/auto-company`.
  - Evidence: `gh variable list -R nicepkg/auto-company` returns HTTP 403, while `gh variable set -R junhengz/auto-company ...` succeeds.
- Hosted runtime origin we are standardizing on: `https://auto-company-sq-autopilot.fly.dev`
  - Note: currently `NXDOMAIN` from this environment, which indicates the Fly app is not deployed (or not publicly provisioned) yet.

## What We Changed

- Added workflows:
  - `.github/workflows/sq-autopilot-ci.yml`
  - `.github/workflows/sq-autopilot-hosted-integration.yml`

## Commands

### 1) Confirm canonical repo access

```bash
gh repo view nicepkg/auto-company --json nameWithOwner,isFork,defaultBranchRef
# isFork=false

gh repo view junhengz/auto-company --json nameWithOwner,isFork,parent
# isFork=true (fork of nicepkg/auto-company)

# Variables access
gh variable list -R nicepkg/auto-company
# expected: HTTP 403 (no permission)

gh variable list -R junhengz/auto-company
# expected: succeeds (may be empty)
```

### 2) Set canonical hosted runtime origin

```bash
gh variable set HOSTED_WORKFLOW_BASE_URL -R junhengz/auto-company \
  --body "https://auto-company-sq-autopilot.fly.dev"

# Verify (prints value)
gh api repos/junhengz/auto-company/actions/variables/HOSTED_WORKFLOW_BASE_URL | jq -r '.name + "=" + .value'
```

### 3) Dispatch hosted integration workflow (manual)

Once `.github/workflows/sq-autopilot-hosted-integration.yml` is on `main`:

```bash
# No override: uses repo variable HOSTED_WORKFLOW_BASE_URL
# (If DNS is still broken, this run will fail; see "Unblock".)
gh workflow run sq-autopilot-hosted-integration -R junhengz/auto-company --ref main

# Find the run
gh run list -R junhengz/auto-company -w sq-autopilot-hosted-integration -L 5
```

## Risks + Rollback

- Risk: scheduled runs will flap red until a real hosted runtime exists at `HOSTED_WORKFLOW_BASE_URL`.
- Rollback options:
  - Temporarily remove the `schedule:` block from `.github/workflows/sq-autopilot-hosted-integration.yml`.
  - Or set `HOSTED_WORKFLOW_BASE_URL` to a known-good deployed runtime origin.

## Unblock: Deploy the Fly runtime (needed for a green baseline)

Pre-reqs:
- Install `flyctl` and authenticate.
- Provide `NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` (real values if you want full Supabase health checks; placeholders are fine for env-health-only).

Fast path (single command; deploy + set var + preflight helper):

```bash
# Requires: flyctl auth + repo write perms
scripts/devops/deploy-sq-autopilot-fly-and-preflight.sh \
  --repo junhengz/auto-company \
  --preflight-require-supabase-health false
```
