# Cycle 005 Hosted Persistence Evidence: Workflow Reliability Changes (QA-Bach)

Date (UTC): 2026-02-14  
Goal: reduce operator error and improve trustworthiness of the preflight gate.

## Changes Shipped
1) Manual preflight is now a real go/no-go:
   - If `workflow_dispatch` runs without any BASE_URL candidates configured/discovered, the workflow fails (red) instead of silently skipping (green).
   - Scheduled runs remain non-noisy: missing candidates continues to be treated as a no-op (green) to avoid repeated failing cron noise.

2) Clearer maintainer next step after a green preflight:
   - Preflight-only run summary now includes the exact `gh variable set CYCLE_005_AUTORUN_ENABLED ...` command.

3) Candidate formatting is normalized before persisting/dispatching (wrapper script):
   - `--candidates` and `--base-url` inputs are normalized to origins, de-duped, and stripped of paths/trailing slashes.
   - This reduces wrong-BASE_URL selection due to copy/paste of full URLs (with `/path`) or inconsistent separators.

4) Make targets (already present) are now fully declared as `.PHONY`:
   - `make cycle-005-preflight`
   - `make cycle-005-preflight-enable-autorun`

## How To Verify (Fast)
1) With no variables configured:
   - Run the workflow manually with `preflight_only=true`.
   - Expected: job fails with summary instructing to set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.

2) With candidates configured:
   - `make cycle-005-preflight`
   - Expected: green run, summary includes `Selected BASE_URL` and `has_supabase_env: true`.

3) Autorun enable is post-green:
   - `make cycle-005-preflight-enable-autorun`
   - Expected: preflight run is green, then wrapper sets `CYCLE_005_AUTORUN_ENABLED=true`.

