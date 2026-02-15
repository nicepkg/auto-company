# QA Notes: Cycle 005 Hosted Persistence Evidence Workflow Improvements

## Scope
- Add a safe “preflight then enable autorun” path in `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`.
- Add Make targets for preflight and preflight-then-enable-autorun.
- Reduce operator error by showing the autorun enable command only when `CYCLE_005_AUTORUN_ENABLED` is not already true in the preflight-only step summary.

## Files Changed
- `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh`
- `Makefile`
- `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
- `docs/operations/cycle-005-hosted-persistence-evidence-maintainer-checklist.md`

## Test Charters
1. CLI argument parsing:
   - `--enable-autorun-after-preflight` forces `--preflight-only` behavior.
   - `--enable-autorun-after-preflight` rejects combination with `--autorun/--enable-autorun/--disable-autorun`.
2. Correct sequencing:
   - Workflow dispatch happens first.
   - `gh run watch --exit-status` gates the autorun enable step.
   - Autorun is set only when the run is green.
3. Regression safety:
   - Existing `--autorun true|false` behavior remains unchanged when not using the new flag.
4. Workflow UX:
   - Preflight-only summary no longer suggests enabling autorun when it is already enabled.

## Execution Notes (Local)
- Not executed end-to-end here (requires GitHub `gh` auth + repo permissions and a real deployed BASE_URL).
- Basic sanity was performed by inspection:
  - New flag sets `PREFLIGHT_ONLY=true` before dispatch.
  - Autorun write occurs only after `gh run watch --exit-status` returns success.

