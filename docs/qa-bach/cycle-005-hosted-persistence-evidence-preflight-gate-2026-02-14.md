# Cycle 005 Hosted Persistence Evidence: Preflight Gate (QA-Bach)

Date (UTC): 2026-02-14  
Scope: hosted persistence evidence workflow preflight signal quality

## Objective
Make it mechanically reliable for a maintainer to:
1. Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (once, correctly formatted).
2. Run a manual dispatch with `preflight_only=true` and get a trustworthy red/green outcome.
3. Enable scheduled refresh (`CYCLE_005_AUTORUN_ENABLED=true`) only after a green preflight.

## The Three Commands (Preferred Path)
Assumes `gh auth login` is already done and you have write permission to repo Actions variables.

1) Set candidates (normalized) and persist:
```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --repo OWNER/REPO \
  --candidates "https://app.example.com https://project.vercel.app" \
  --set-variable
```

2) Preflight-only run (no evidence, no PR):
```bash
make cycle-005-preflight
```

3) Enable autorun only after a green preflight:
```bash
make cycle-005-preflight-enable-autorun
```

## What "Green Preflight" Means (Acceptance)
The preflight-only workflow run must be **green** and include in the run summary:
- a selected `BASE_URL`
- `env-health` succeeded
- `has_supabase_env: true`

Non-go (must be red):
- Missing `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (manual runs now fail, to avoid false greens)
- Wrong domain (marketing/static) where `/api/workflow/env-health` is not JSON/200
- Hosted runtime reachable but missing Supabase env vars (requires hosting provider config + redeploy)

## Fast Checks (No Guesswork)
These should work against the selected base url:
```bash
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e '.ok == true'
curl -sS "<BASE_URL>/api/workflow/env-health" | jq -e '.env.NEXT_PUBLIC_SUPABASE_URL == true and .env.SUPABASE_SERVICE_ROLE_KEY == true'
```

## Risk Notes (Why These Changes Exist)
- A successful-but-skipped workflow run is a classic “false green”. The preflight gate must be a real go/no-go signal.
- Formatting drift in candidate lists (paths, trailing slashes, duplicates) causes avoidable wrong-BASE_URL selection. The wrapper now normalizes candidate strings before persisting/dispatching.

