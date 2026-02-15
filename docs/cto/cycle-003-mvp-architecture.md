# Cycle 003 CTO Architecture - Security Questionnaire Autopilot MVP

## 1) Constraints and Business Requirements
- Ship an MVP workflow in this cycle that is implementable by one engineer with managed services.
- Enforce non-negotiable quality gates:
  - `G1 Citation Gate`: no answer may exist in draft/export state without at least one evidence citation.
  - `G2 Human Approval Gate`: export is blocked until all answers are explicitly approved or edited+approved by a human reviewer.
  - `G3 Margin Gate`: processing path must capture reviewer minutes and LLM/infra cost per questionnaire; warn/block below margin floor.
- Pricing floor for pilots is fixed:
  - `$2,000` onboarding + `$1,800/mo` includes `12` questionnaires + `$150` overage.
- Target this cycle: architecture and delivery artifacts that unblock shipping and onboarding `3` paid design partners.

## 2) Architecture Options With Tradeoffs

### Option A (Recommended): Monolith + Queue + Postgres/pgvector
- `Next.js` app (API routes + UI), `Postgres` for transactional data, `pgvector` for retrieval, background jobs for ingestion/drafting.
- Tradeoffs:
  - Pros: fastest to ship, low integration risk, single deployable unit, easy to reason about failure domains.
  - Cons: queue worker and web app share codebase/runtime constraints; requires disciplined boundaries.

### Option B: Service-Split (Ingestion service + Answer service + Review app)
- Independent services with explicit APIs and async events between them.
- Tradeoffs:
  - Pros: cleaner long-term scaling and team ownership boundaries.
  - Cons: over-complex for current stage; higher ops burden and slower cycle time.

### Option C: Workflow-first with Temporal/Orchestration platform
- Model full pipeline as durable workflows.
- Tradeoffs:
  - Pros: strong observability/retry semantics for long-running jobs.
  - Cons: unnecessary platform overhead for MVP; team can emulate with queue + state machine first.

## 3) Recommended Architecture (Option A)

### Component Map
- `Web/API`: Next.js app for uploads, question review, approval, and export.
- `Storage`: object storage for uploaded artifacts and export packages.
- `DB`: Postgres for entities + audit log; pgvector for chunk embeddings.
- `Worker`: async ingestion, chunking, retrieval, draft generation, and export assembly.
- `LLM provider`: answer generation constrained by retrieved evidence snippets.

### Data Flow (Failure-Oriented)
1. User uploads docs/questionnaire.
2. Worker parses files into normalized `questionnaire_items` and evidence chunks.
3. Retrieval fetches top evidence snippets for each question.
4. Draft answer generated with structured output: `answer_text`, `citations[]`, `confidence`.
5. `G1` blocks state transition if citations are empty.
6. Reviewer edits/approves each item in UI.
7. `G2` checks all items approved before export.
8. Export job builds package (`xlsx/csv/docx + citation appendix + audit log`).
9. `G3` computes contribution estimate and flags overage/margin risk.

### API-First Contracts (MVP)
- `POST /api/workspaces/:id/uploads`
- `POST /api/questionnaires`
- `POST /api/questionnaires/:id/draft`
- `GET /api/questionnaires/:id/items`
- `POST /api/items/:id/approve`
- `POST /api/items/:id/reject`
- `POST /api/questionnaires/:id/export`
- `GET /api/questionnaires/:id/export-package`

### Minimal Domain Model
- `workspace`
- `evidence_document`
- `evidence_chunk`
- `questionnaire`
- `questionnaire_item`
- `answer_draft`
- `citation`
- `approval_event`
- `export_package`
- `cost_ledger`

## 4) Key Risks and Failure Modes

| Risk | Failure Mode | Detection | Mitigation |
|---|---|---|---|
| Answer integrity | Hallucinated answer without support | Citation coverage metric + `G1` hard fail | Block uncited drafts, require source snippet IDs, log overrides |
| Liability | Unreviewed content exported | Approval completeness check | `G2` hard gate on export endpoint |
| Throughput | Review bottleneck | Reviewer minutes/questionnaire trend | Prioritize recurring control library; async queue retries |
| Margin erosion | High manual review time or token burn | Contribution margin per questionnaire | `G3` warnings + overage enforcement + scope cap |
| Data freshness | Outdated evidence used | Evidence age metadata | Freshness threshold + reviewer warning banner |
| Parser reliability | Broken XLSX/DOCX extraction | Parse error rate by format | fallback parser path + manual mapping UI |

## 5) Technology Recommendations and Rationale
- `Next.js (TypeScript)`: fastest path for integrated UI + API in one deployable.
- `Postgres + pgvector (Supabase/Neon class managed)`: transactional integrity + retrieval in one DB.
- `Redis-backed queue (Upstash/QStash or BullMQ on managed Redis)`: durable async jobs without orchestration overkill.
- `S3-compatible storage (Cloudflare R2/S3)`: cheap object storage and export packaging.
- `OpenAI Responses/Chat API`: structured JSON output with citation schema.
- `Observability`: Sentry + basic metrics (queue lag, citation coverage, approval lag, gross margin proxy).

## 6) Complexity and Operations Overhead Estimate
- Build complexity: `Medium` (one engineer, 10-14 focused days for functional MVP if scope is held).
- Ops overhead: `Low-Medium` with managed services.
- Expected toil hotspots:
  - file parsing edge cases
  - long-running job retries/timeouts
  - reviewer UX for fast approvals
- Reliability SLO (pilot phase):
  - `99.0%` successful draft job completion within `15 min`
  - `0` exports with missing citations
  - `0` exports without full approval trail

## 7) Mandatory Release Gates (Must Pass)
1. `Gate-QA-01`: Citation coverage = `100%` for exported answers.
2. `Gate-QA-02`: Export requests with unapproved items fail with clear error.
3. `Gate-FIN-01`: Questionnaire-level contribution margin tracker visible before final export.
4. `Gate-OPS-01`: Audit log records every generation, edit, approval, and export event.

## Exact Files to Create/Modify (MVP Build Targets)
- `projects/security-questionnaire-autopilot/package.json`
- `projects/security-questionnaire-autopilot/src/app/(app)/questionnaires/[id]/page.tsx`
- `projects/security-questionnaire-autopilot/src/app/api/questionnaires/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/questionnaires/[id]/draft/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/items/[id]/approve/route.ts`
- `projects/security-questionnaire-autopilot/src/app/api/questionnaires/[id]/export/route.ts`
- `projects/security-questionnaire-autopilot/src/lib/retrieval.ts`
- `projects/security-questionnaire-autopilot/src/lib/citation-gate.ts`
- `projects/security-questionnaire-autopilot/src/lib/margin-gate.ts`
- `projects/security-questionnaire-autopilot/src/lib/exporter.ts`
- `projects/security-questionnaire-autopilot/src/workers/ingest-worker.ts`
- `projects/security-questionnaire-autopilot/src/workers/draft-worker.ts`
- `projects/security-questionnaire-autopilot/prisma/schema.prisma`
- `projects/security-questionnaire-autopilot/prisma/migrations/0001_init.sql`
- `projects/security-questionnaire-autopilot/docs/runbook.md`

## Next Action
Full-stack + DevOps should scaffold `projects/security-questionnaire-autopilot/` and implement `Gate-QA-01` and `Gate-QA-02` first, then wire draft/export path end-to-end.
