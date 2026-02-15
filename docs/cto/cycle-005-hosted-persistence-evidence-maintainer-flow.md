# Cycle 005 Hosted Persistence Evidence: Maintainer Flow

Goal: a maintainer can reliably (1) set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, (2) run a manual preflight with `preflight_only=true`, and (3) enable `CYCLE_005_AUTORUN_ENABLED=true` only after a green preflight.

Workflow: `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

## Why This Exists (Reliability Framing)
- Everything fails all the time: wrong `BASE_URL` and missing hosted runtime env are the highest-cost failure modes.
- The workflow now supports “safe writes” of repo variables and “schedule gating” only after a verified preflight.

## Required Repo Variables
- `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`: `2-4` deployed Next.js *workflow runtime* origins (space/comma/newline separated). These must serve `GET /api/workflow/env-health`.
- `CYCLE_005_AUTORUN_ENABLED`: set to `true` only after preflight is green (enables scheduled refresh runs).

## Manual Dispatch (UI) Checklist
Location: GitHub `Actions` tab -> `cycle-005-hosted-persistence-evidence` -> `Run workflow`.

1. Set candidates (one-time, can be done via workflow)
- Inputs:
  - `base_url`: paste `2-4` candidates (examples: `https://app.example.com https://project.pages.dev`)
  - `persist_base_url_candidates`: `true`
  - `preflight_only`: `true`
  - `enable_autorun_after_preflight`: `false` (recommended on first run)
- Expected:
  - Step summary shows `persisted_repo_variable: HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
  - Preflight selects a single `BASE_URL` and `env-health` succeeds.

2. Preflight-only run (repeatable)
- Inputs:
  - `base_url`: leave empty (recommended once repo variable is set)
  - `persist_base_url_candidates`: `false`
  - `preflight_only`: `true`
  - `skip_sql_apply`: `true` (default; also runs `supabase-health`)
- Expected:
  - Step summary includes:
    - `Selected BASE_URL`
    - `has_supabase_env: true`
    - `supabase-health ... ok`

3. Enable scheduled refresh (only after green preflight)
- Option A (workflow does it safely):
  - Re-run with:
    - `preflight_only: true`
    - `enable_autorun_after_preflight: true`
  - Expected:
    - Step summary includes `schedule_gate_enabled: CYCLE_005_AUTORUN_ENABLED=true`
- Option B (manual repo variable set):
  - Set `CYCLE_005_AUTORUN_ENABLED=true` in:
    - Settings -> Secrets and variables -> Actions -> Variables

4. Full evidence run (creates/updates evidence PR)
- Inputs:
  - `preflight_only: false`
  - `base_url`: leave empty (use repo variable)
  - `skip_sql_apply: true` (unless you explicitly need CI to apply the SQL bundle)
- Expected:
  - Artifacts uploaded (smoke + db evidence JSON)
  - PR created/updated on branch `cycle-005-hosted-persistence-evidence`

## Fast Failure Modes (What To Fix)
- “No BASE_URL candidates”:
  - Fix: set/persist `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to the deployed app origin(s), not a marketing site.
- `env-health` fails or returns missing Supabase env vars:
  - Fix: configure hosted runtime env vars and redeploy:
    - `NEXT_PUBLIC_SUPABASE_URL`
    - `SUPABASE_SERVICE_ROLE_KEY`
- `supabase-health` fails (when `skip_sql_apply=true`):
  - Fix: apply the SQL bundle to the correct Supabase project (or run with `skip_sql_apply=false` and provide `SUPABASE_DB_URL` secret).

## What To Pull From Artifacts
- `cycle-005-hosted-base-url-probe`: candidate probe table (quickly identifies wrong domains)
- `cycle-005-hosted-preflight`: selected base URL + env/supabase health JSON

