# Cycle 005 Hosted Persistence Evidence Workflow (Critic-Munger)

## Verdict: support (with guardrails)
The current workflow design is directionally correct (fail-fast preflight, scheduled-run gate, stable PR branch). The main operational risk is humans enabling the schedule gate before proving the runtime is correctly targeted and configured. The changes in this repo reduce that risk by making “green preflight then enable autorun” the default safe path.

## Key Risks / Potential Fatal Flaws
- Wrong BASE_URL: candidate list points to marketing/static origins, yielding 404/HTML and wasting runs.
- Missing hosted Supabase env vars: the runtime is reachable but has `NEXT_PUBLIC_SUPABASE_URL` or `SUPABASE_SERVICE_ROLE_KEY` unset; schedule then fails every 6 hours.
- Incentive bias: “get it running” pressure leads to prematurely setting `CYCLE_005_AUTORUN_ENABLED=true` and creating repeated failing scheduled runs.
- Permission edge cases: maintainers can dispatch workflows but cannot set repo variables via `gh`, causing a false sense of completion if the enable step silently fails.
- Hidden complexity: multiple legacy var names exist; maintainers may “set the wrong one” and assume selection will work.

## Concrete Failure Scenarios (Inversion)
1. Schedule spam failure:
   - Operator sets `CYCLE_005_AUTORUN_ENABLED=true` first.
   - Hosted runtime still lacks Supabase env vars.
   - Cron triggers every 6 hours; each run fails preflight; noise accumulates; maintainer disables Actions instead of fixing root cause.
2. Silent wrong-origin failure:
   - Candidate list contains a marketing domain that returns 200 HTML.
   - A naive probe passes “reachable” checks elsewhere, but `/api/workflow/env-health` fails.
   - Maintainer retries randomly, burns time, and concludes “workflow is flaky”.
3. Illusory readiness:
   - Preflight passes env-health but Supabase schema/seed is not actually ready (when `skip_sql_apply=true`, supabase-health catches this; when people skip preflight and run full evidence, they discover it late).

## Guardrails Now Implemented (This Repo)
- Safe CLI sequencing:
  - `scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --enable-autorun-after-preflight`
  - This forces `preflight_only=true`, watches for a green run, then sets `CYCLE_005_AUTORUN_ENABLED=true` only after success.
- Workflow UI guidance:
  - The preflight-only step summary now suggests enabling autorun only when it is not already enabled.
- Maintainer checklist updated:
  - `docs/operations/cycle-005-hosted-persistence-evidence-maintainer-checklist.md` now recommends the safe flow explicitly.

## Minimal Maintainer Flow (What “Good” Looks Like)
1. Set candidates once:
   - Set repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to 2-4 deployed Next.js origins serving `/api/workflow/env-health`.
2. Run manual preflight-only:
   - Actions UI: dispatch with `preflight_only=true` (or run `make cycle-005-preflight`).
   - Green preflight means: base URL selection succeeded, env-health ok, and (when `skip_sql_apply=true`) supabase-health ok.
3. Only then enable schedule:
   - Set repo variable `CYCLE_005_AUTORUN_ENABLED=true` (or run `make cycle-005-preflight-enable-autorun`).

## Do Not Proceed (When To Veto)
- If you cannot name a deployed runtime origin that serves `/api/workflow/env-health`, stop and fix deployments first. No amount of workflow tweaking will compensate.
- If hosted runtime env vars cannot be set (organizational/policy constraint), stop: scheduled runs will remain noisy and the evidence plan is not viable.

