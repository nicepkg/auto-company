# Cycle 005 Hosted Persistence Evidence: Exploratory Test Charters (QA-Bach)

Date (UTC): 2026-02-14

## Primary Quality Risks
- False green preflight: a run that is green but does not prove readiness to run evidence.
- Wrong BASE_URL: selecting marketing/static domains or preview deployments.
- Hidden configuration debt: repo variable not set, hosted runtime env not set, schedule gate not enabled.
- Operator error: candidates pasted with paths, commas, quotes, duplicates.

## Charters (30-45 min sessions)
1) **Candidates Configuration**
   - Start with no repo variables set; run manual preflight.
   - Expectation: workflow fails with explicit instruction to set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.
   - Then set candidates with mixed formatting: with paths, trailing slashes, commas, newlines, duplicates.
   - Expectation: wrapper script normalizes, workflow selects correct origin.

2) **Wrong Domain Rejection**
   - Provide a known marketing/static domain as candidate and one real runtime.
   - Expectation: probe report makes mismatch obvious, selection chooses runtime only.

3) **Hosted Runtime Missing Supabase Env**
   - Provide a candidate that returns `ok=true` but `env.*` booleans false.
   - Expectation: preflight fails with actionable hosting-provider guidance and no evidence steps run.

4) **Preflight-Only Stop Condition**
   - Dispatch with `preflight_only=true`.
   - Expectation: workflow exits after preflight steps; Node install, evidence capture, and PR creation are skipped.

5) **Autorun Gate Behavior**
   - Scheduled trigger with `CYCLE_005_AUTORUN_ENABLED` unset/false.
   - Expectation: run is skipped (success) with clear summary explaining the gate.
   - After setting `CYCLE_005_AUTORUN_ENABLED=true`, scheduled run proceeds past BASE_URL selection.

## Evidence to Capture
- GitHub Actions run summary screenshot/text.
- Uploaded artifacts:
  - `cycle-005-hosted-base-url-probe`
  - `cycle-005-hosted-preflight`
- If failing: `preflight/select-base-url.err` plus `preflight/base-url-probe.txt`.

