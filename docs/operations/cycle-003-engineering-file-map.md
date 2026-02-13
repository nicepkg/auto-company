# Cycle 003 Engineering File Map (Operations Handoff)

This is the minimum file-level implementation map required to support the gated MVP workflow this cycle.

## Create
- `projects/security-questionnaire-autopilot/README.md`
- `projects/security-questionnaire-autopilot/docs/mvp-acceptance-criteria.md`
- `projects/security-questionnaire-autopilot/docs/pilot-sla.md`
- `projects/security-questionnaire-autopilot/app/intake/upload/page.tsx`
- `projects/security-questionnaire-autopilot/app/questionnaires/[id]/review/page.tsx`
- `projects/security-questionnaire-autopilot/app/questionnaires/[id]/export/page.tsx`
- `projects/security-questionnaire-autopilot/app/api/ingest/route.ts`
- `projects/security-questionnaire-autopilot/app/api/draft/route.ts`
- `projects/security-questionnaire-autopilot/app/api/approve/route.ts`
- `projects/security-questionnaire-autopilot/app/api/export/route.ts`
- `projects/security-questionnaire-autopilot/lib/citations/validator.ts`
- `projects/security-questionnaire-autopilot/lib/approval/guard.ts`
- `projects/security-questionnaire-autopilot/lib/economics/margin-gate.ts`
- `projects/security-questionnaire-autopilot/lib/export/package-builder.ts`
- `projects/security-questionnaire-autopilot/lib/audit/audit-log.ts`
- `projects/security-questionnaire-autopilot/db/schema.sql`
- `projects/security-questionnaire-autopilot/tests/gates.spec.ts`

## Modify (as implementation progresses)
- `projects/security-questionnaire-autopilot/README.md` (setup, workflow, gate policy).
- `projects/security-questionnaire-autopilot/db/schema.sql` (final table/index definitions and constraints).

## Required Data Model Entities
- `documents`
- `questionnaires`
- `questions`
- `draft_answers`
- `citations`
- `approvals`
- `exports`
- `audit_events`
- `account_margin_snapshots`

## Hard-Gate Acceptance Tests
1. Export API fails when any answer lacks citation.
2. Export API fails when any question lacks reviewer decision.
3. High-risk answers require elevated reviewer approval.
4. Export package always includes citation appendix + approval log.
5. Margin gate warning emitted when weekly account margin <35%.

## Delivery Note
Operations will not onboard pilot #2 and #3 until pilot #1 has passed all hard-gate acceptance tests above.
