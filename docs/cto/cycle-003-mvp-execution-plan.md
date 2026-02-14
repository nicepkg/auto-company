# Cycle 003 CTO Execution Plan - File-Level Build Sequence

## Objective
Ship a working MVP path this cycle:
`ingest -> draft with citations -> human approval -> export package`
with hard enforcement for citation, approval, and margin protection.

## Delivery Sequence

### Phase 1: Project Scaffold and Core Schema (Day 1)
1. Create app scaffold under `projects/security-questionnaire-autopilot/`.
2. Define DB schema and migrations for:
   - questionnaires, items, drafts, citations, approvals, exports, cost ledger.
3. Add seed script with one synthetic questionnaire fixture.

Acceptance:
- App boots locally.
- Migration applies cleanly.
- Fixture questionnaire visible via API.

### Phase 2: Ingestion + Parsing Pipeline (Day 2-3)
1. Implement upload endpoint and object storage persistence.
2. Build worker parsing for `xlsx/csv/docx/pdf -> questionnaire_item`.
3. Chunk evidence docs and store embeddings.

Acceptance:
- At least one sample questionnaire and one policy doc parse successfully.
- Parser errors are captured in `audit_log` with file-level diagnostics.

### Phase 3: Source-Grounded Drafting + Citation Gate (Day 4-5)
1. Implement retrieval pipeline (`top-k` evidence chunk lookup).
2. Generate draft answers with strict JSON schema:
   - `answer_text`
   - `citations[]` (chunk IDs + source doc refs)
   - `confidence`
3. Add `citation-gate` precondition:
   - reject any draft item with empty citations.

Acceptance:
- `100%` drafted items contain `>=1` citation.
- Any uncited generation attempt is blocked and logged.

### Phase 4: Human Approval Workflow + Export Gate (Day 6-7)
1. Reviewer UI to approve/edit/reject each item.
2. Approval API writes immutable approval events.
3. Export endpoint verifies all items approved before package creation.
4. Build export package:
   - completed questionnaire
   - citation appendix
   - audit log extract.

Acceptance:
- Export fails when any item is not approved.
- Export succeeds only with full approval trail and citations.

### Phase 5: Margin Protection Instrumentation (Day 7-8)
1. Track per-questionnaire:
   - reviewer minutes
   - model tokens/cost
   - infra processing estimates.
2. Implement `margin-gate` policy:
   - warn when projected contribution margin `<60%`.
   - flag mandatory overage when monthly count exceeds `12`.

Acceptance:
- Dashboard/API shows contribution estimate before export.
- Overage and low-margin alerts fire deterministically.

## Hard Gate Test Matrix
| Gate | Test Case | Expected |
|---|---|---|
| `G1 Citation` | Force model output with empty citations | Draft item rejected |
| `G2 Approval` | Try export with 1 unapproved item | Export blocked |
| `G3 Margin` | Simulate high reviewer minutes + token burn | Margin warning + audit event |

## Exact Files to Create/Modify
- `projects/security-questionnaire-autopilot/src/app/api/uploads/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/questionnaires/[id]/items/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/questionnaires/[id]/draft/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/items/[id]/approve/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/items/[id]/reject/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/questionnaires/[id]/export/route.ts`
- `projects/security-questionnaire-autopilot/src/lib/parser/index.ts`
- `projects/security-questionnaire-autopilot/src/lib/retrieval.ts`
- `projects/security-questionnaire-autopilot/src/lib/citation-gate.ts`
- `projects/security-questionnaire-autopilot/src/lib/approval-gate.ts`
- `projects/security-questionnaire-autopilot/src/lib/margin-gate.ts`
- `projects/security-questionnaire-autopilot/src/lib/exporter.ts`
- `projects/security-questionnaire-autopilot/src/lib/cost-ledger.ts`
- `projects/security-questionnaire-autopilot/src/workers/ingest-worker.ts`
- `projects/security-questionnaire-autopilot/src/workers/draft-worker.ts`
- `projects/security-questionnaire-autopilot/src/workers/export-worker.ts`
- `projects/security-questionnaire-autopilot/src/components/review/ApprovalTable.tsx`
- `projects/security-questionnaire-autopilot/prisma/schema.prisma`
- `projects/security-questionnaire-autopilot/tests/gates/citation-gate.test.ts`
- `projects/security-questionnaire-autopilot/tests/gates/approval-gate.test.ts`
- `projects/security-questionnaire-autopilot/tests/gates/margin-gate.test.ts`

## Ownership (You Build It, You Run It)
- Full-stack owns build + runtime behavior for API/UI/workers.
- QA owns gate test cases and release checks.
- DevOps owns queue, DB, storage reliability and monitoring.
- CTO sign-off requires passing all three hard gates in staging.

## Next Action
Engineering should start Phase 1 immediately and demo a failing-then-passing `G1` citation test before implementing export.
