# Cycle 003 Hosted Workflow QA Execution - Pilot #1

Date: 2026-02-13
Role: qa-bach

## 1) Current Quality Risk Profile

| Risk ID | Risk | Probability | Impact | Current Status | Evidence |
|---|---|---|---|---|---|
| R1 | Uncited answers reach export | Medium | Critical | Controlled in current implementation | `projects/security-questionnaire-autopilot/runs/pilot1-citation-neg-2026-02-13/draft_answers.json` (blocked) |
| R2 | Export bypasses human approval | Medium | Critical | Controlled in current implementation | export-before-approval attempt returned exit code `1`; approved path exported successfully |
| R3 | Pilot pricing or margin below floor | High | High | Controlled in current implementation | `docs/qa/cycle-003-pilot1-pricing-pass.json`, `docs/qa/cycle-003-pilot1-pricing-fail.json` |
| R4 | Hosted Next.js + Supabase path diverges from validated gates | High | Critical | Open blocker | No hosted app/API/Supabase artifacts present yet in `projects/security-questionnaire-autopilot/` |
| R5 | Live ingest -> draft -> approve -> export observability gaps | Medium | High | Partial | CLI artifacts present; hosted telemetry path not yet validated |

## 2) Targeted Test Strategy (Execution)

### Executed this cycle (completed)
1. Run hard-gate checks on live pilot-style flow using run ID `pilot1-live-2026-02-13`.
2. Execute negative-path checks for each hard gate.
3. Capture gate evidence files in `docs/qa/` and run artifacts in `projects/security-questionnaire-autopilot/runs/`.

### Required before hosted pilot release (remaining)
1. Mirror the same checks against Next.js API routes and Supabase-backed state.
2. Add tenant-boundary and RLS checks for citation, approval, and export endpoints.
3. Add hosted E2E smoke covering upload -> draft -> approve -> export with audit trail assertions.

### Check status snapshot
- Gate checks summary: `docs/qa/cycle-003-pilot1-gate-check-results.csv`
- Hard gates in current implementation: `PASS`
- Hosted parity requirement: `BLOCKED`

## 3) Exploratory Test Charters

1. **Charter: Hosted gate parity drift**
   - Mission: Find any path where API behavior differs from validated CLI gate rules.
   - Focus: draft gating, approval state transitions, export eligibility.

2. **Charter: Supabase authorization abuse**
   - Mission: Attempt cross-workspace access to draft, approval, and export records.
   - Focus: RLS policy correctness and service-role misuse.

3. **Charter: Concurrency and stale state**
   - Mission: Trigger simultaneous reviewer edits/approvals and observe state integrity.
   - Focus: lost updates, stale approvals, export race conditions.

4. **Charter: Live ingest robustness**
   - Mission: Stress ingest with malformed/large files and verify failure transparency.
   - Focus: parser failures, partial ingest state, retry safety.

## 4) Recommended Automation Scope and Tools

1. `pytest` for deterministic gate unit/integration checks on existing logic.
2. `Playwright` for hosted smoke: ingest -> draft -> approve -> export.
3. API contract checks (Next.js route tests) for gate responses and error codes.
4. Scheduled pricing/margin gate check job tied to pilot account telemetry.

## 5) Concrete Edge and Boundary Scenarios

1. Draft contains one uncited answer while others are cited.
2. Export requested with missing `approval.json` or incomplete approvals.
3. Approval decision exists but reviewer identity/timestamp missing.
4. Deal at exact floor values with margin near threshold (rounding/precision risk).
5. Overage billing boundary at 12 vs 13 questionnaires.
6. Concurrent approval + export requests on same questionnaire.
7. Source deleted or version-changed after draft but before export.
8. Supabase row ownership mismatch between uploader and reviewer.

## 6) Pilot #1 Execution Evidence

### Happy path completed
- Ingest: `PASS`
- Draft: `PASS`
- Approve: `PASS`
- Export: `PASS`
- Export bundle: `/tmp/pilot1-live-2026-02-13-export.zip`
- Manifest evidence: `projects/security-questionnaire-autopilot/runs/pilot1-live-2026-02-13/export_package/manifest.json`

### Negative-path gate checks completed
- Citation gate block (`G1`): `PASS` (blocked uncited question `Q-NEG-001`)
- Approval gate block (`G2`): `PASS` (export before approval returned non-zero)
- Pricing/margin gate block (`G3`): `PASS` (below-floor deal rejected)

Structured results: `docs/qa/cycle-003-pilot1-gate-check-results.csv`

## 7) Issue Log (Bug Standard)

### BUG-QA-003-001: Hosted workflow parity not yet testable
- Environment: local repo `projects/security-questionnaire-autopilot/` on 2026-02-13.
- Repro steps:
1. Inspect project tree for Next.js app routes and Supabase integration artifacts.
2. Compare with required hosted workflow scope (ingest -> draft -> approve -> export).
- Expected: hosted route layer and Supabase-backed workflow available for QA execution.
- Actual: only CLI implementation is present; hosted route layer not available.
- Severity: Critical.

Next Action: Implement the Next.js + Supabase hosted route/state layer, then rerun `G1/G2/G3` via hosted API + Playwright smoke for pilot #1 release sign-off.
