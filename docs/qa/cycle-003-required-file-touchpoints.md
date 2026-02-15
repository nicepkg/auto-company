# Cycle 003 Required File Touchpoints (QA Handoff To Engineering)

This is the minimum implementation surface QA expects for enforceable gates.

## Proposed MVP Codebase Root
`projects/security-questionnaire-autopilot/`

## Files To Create (Core Gate Enforcement)
1. `projects/security-questionnaire-autopilot/src/domain/citation-gate.ts`
2. `projects/security-questionnaire-autopilot/src/domain/approval-gate.ts`
3. `projects/security-questionnaire-autopilot/src/domain/margin-gate.ts`
4. `projects/security-questionnaire-autopilot/src/domain/export-eligibility.ts`
5. `projects/security-questionnaire-autopilot/src/lib/audit-log.ts`
6. `projects/security-questionnaire-autopilot/src/lib/review-metrics.ts`

## Files To Create (API / Workflow)
1. `projects/security-questionnaire-autopilot/src/app/api/ingest/route.ts`
2. `projects/security-questionnaire-autopilot/src/app/api/draft/route.ts`
3. `projects/security-questionnaire-autopilot/src/app/api/answers/[answerId]/approve/route.ts`
4. `projects/security-questionnaire-autopilot/src/app/api/answers/[answerId]/edit/route.ts`
5. `projects/security-questionnaire-autopilot/src/app/api/export/route.ts`
6. `projects/security-questionnaire-autopilot/src/app/api/contracts/route.ts`

## Files To Create (Checks / Tests)
1. `projects/security-questionnaire-autopilot/tests/unit/citation-gate.test.ts`
2. `projects/security-questionnaire-autopilot/tests/unit/approval-gate.test.ts`
3. `projects/security-questionnaire-autopilot/tests/unit/margin-gate.test.ts`
4. `projects/security-questionnaire-autopilot/tests/integration/parse-draft-approve-export.test.ts`
5. `projects/security-questionnaire-autopilot/tests/integration/export-blocks-on-uncited.test.ts`
6. `projects/security-questionnaire-autopilot/tests/integration/export-blocks-without-approval.test.ts`
7. `projects/security-questionnaire-autopilot/tests/e2e/pilot-happy-path.spec.ts`
8. `projects/security-questionnaire-autopilot/tests/e2e/approval-bypass-attempt.spec.ts`

## Files To Modify (When App Scaffold Exists)
1. `projects/security-questionnaire-autopilot/package.json`
2. `projects/security-questionnaire-autopilot/.github/workflows/ci.yml`
3. `projects/security-questionnaire-autopilot/README.md`

## CI Policy Requirements
1. `ci.yml` must block merge on failure of citation/approval gate tests.
2. E2E smoke must run before release tag or pilot deployment.
3. Daily scheduled check must validate review-time telemetry and pricing-floor enforcement.

## Data Fixtures To Add
1. `projects/security-questionnaire-autopilot/tests/fixtures/questionnaires/`
2. `projects/security-questionnaire-autopilot/tests/fixtures/evidence/`
3. `projects/security-questionnaire-autopilot/tests/fixtures/expected-exports/`

Fixture minimum:
- 10 questionnaire templates (mixed XLSX/CSV/DOCX),
- 3 conflicting policy-version sets,
- 1 intentionally sparse evidence set for negative-path testing.
