# Cycle 003 Hosted API Gate Validation

Date: 2026-02-13
Role: qa-bach

## Hosted Runs
- Happy-path hosted run: `pilot-hosted-smoke-20260213-120836`
- Citation negative run: `pilot-hosted-neg-20260213-120919`
- Approval-gate negative + recovery run: `pilot-hosted-export-gate-20260213-120919`

## Results
- `G1 Citation Gate`:
  - Pass (negative): `docs/qa/cycle-003-hosted-citation-gate-fail.json`
  - Expected block observed with `uncitedQuestionIds=["Q-NEG-001"]`.
- `G2 Human Approval Gate`:
  - Pass (negative): `docs/qa/cycle-003-hosted-approval-gate-fail.json`
  - Expected block observed with `Export blocked: approval gate not satisfied.`
- `G2 Human Approval Gate`:
  - Pass (positive): `docs/qa/cycle-003-hosted-export-pass.json`
  - Export succeeds only after explicit approval payload.
- `G3 Pricing/Margin Gate`:
  - Pass (negative): `docs/qa/cycle-003-hosted-pricing-gate-fail.json`
  - Below-floor pricing correctly rejected.
- `Hosted Happy Path`:
  - Pass (positive): `projects/security-questionnaire-autopilot/runs/pilot-hosted-smoke-20260213-120836/export_package/manifest.json`

## QA Conclusion
Hosted API parity with CLI hard gates is now demonstrable for pilot execution. Remaining release risk is environment hardening (Node 20 runtime alignment + Supabase project wiring), not gate logic correctness.

## Next Action
Run the same hosted checks against the production Supabase environment and add one customer-originated run ID to the sales tracker.
