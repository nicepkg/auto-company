# Cycle 015: Make Cycle 005 Hosted Persistence Evidence Runnable (CTO-Vogels)

Date: 2026-02-13

## Objective

Reduce operator error and time-to-signal when running:

- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

by making BASE_URL selection, secrets preflight, and runtime smoke checks deterministic and automatable.

## What Changed (Shipped)

1. Single-command operator runner (local)
   - `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`
   - Responsibilities:
     - deterministically select the correct deployed Next.js runtime `BASE_URL` (probes `/api/workflow/env-health`)
     - dispatch the workflow via `gh` and optionally watch it to completion
     - enforce `SUPABASE_DB_URL` presence when `skip_sql_apply=false`

2. Runbooks now point to the runner
   - Updated Cycle 005 operator/devops/sales docs that previously referenced a non-existent wrapper script path.

## Why This Design (Vogels Lens)

- Everything fails, all the time:
  - The dominant failure mode was “wrong BASE_URL” (static/marketing domain, stale preview, wrong service).
  - The runner selects BASE_URL only by probing runtime-owned endpoints, not by naming conventions.
- You build it, you run it:
  - The operational contract is now a script that can be run repeatedly with low cognitive overhead.
  - It fails fast locally and points at the exact failing endpoint.
- Blast radius:
  - Default is `skip_sql_apply=true` (avoid applying schema changes from CI unless explicitly intended).
  - When SQL apply is enabled, the runner blocks dispatch unless the required secret exists.

## Operator Path (Recommended)

1. Curate 2-4 candidate origins in `docs/devops/base-url-candidates.template.txt`.
2. Run:

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --skip-sql-apply true
```

Pass criteria:
- Runner successfully dispatches the workflow and the run succeeds.
- GitHub Actions run succeeds and opens a PR appending evidence into `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.
