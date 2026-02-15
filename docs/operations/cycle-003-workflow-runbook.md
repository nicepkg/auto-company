# Cycle 003 Workflow Runbook - Gated MVP Delivery

## Objective
Ship an end-to-end delivery workflow that always follows:
`ingest docs/questionnaires -> source-grounded draft answers with citations -> mandatory human approval -> export package`.

## Workflow States and Exit Criteria

## State 1: Intake + Ingest
- Inputs required:
  - customer evidence docs (SOC 2, policies, prior questionnaires, architecture/security docs),
  - target questionnaire file (XLSX/CSV/DOCX/PDF where possible),
  - customer context (product scope, environment, exclusions).
- Exit criteria:
  - files uploaded and checksum logged,
  - questionnaire parsed into normalized question records,
  - evidence index created and version-stamped.

## State 2: Draft with Source Grounding
- System behavior:
  - every drafted answer must include `source_id` and `source_excerpt` references,
  - if no supporting source is found, answer status must be `NEEDS_SOURCE` (not auto-filled).
- Exit criteria:
  - draft generated for all parsed questions,
  - each question tagged with risk tier (`high`, `medium`, `low`).

## State 3: Citation Gate (Hard Block)
- Mandatory checks:
  - `citation_coverage = 100%` for all non-empty answers,
  - high-risk answers must reference at least one primary policy/control source,
  - stale-source warnings raised where evidence freshness fails policy.
- Block conditions:
  - any answer without citation,
  - any citation link that cannot be resolved to stored source evidence.

## State 4: Human Approval Gate (Hard Block)
- Required reviewer action per question:
  - `APPROVE`, `EDIT_APPROVE`, or `REJECT`.
- Additional high-risk rule:
  - high-risk questions require senior reviewer approval.
- Block conditions:
  - unreviewed question exists,
  - rejected question unresolved,
  - reviewer identity/timestamp missing.

## State 5: Export Package
- Required outputs:
  - completed questionnaire in requested format,
  - citation appendix (question -> source mapping),
  - approval log (who approved, when, what changed),
  - exception log (`NEEDS_SOURCE`, rejects, unresolved items).
- Exit criteria:
  - package marked `READY_TO_SEND`,
  - immutable export bundle ID created for audit.

## Mandatory Gate Policy (Non-Negotiable)
1. **No uncited answers**: uncited answers cannot be exported.
2. **Human approval required**: no answer can bypass reviewer action.
3. **Margin protection**:
   - include up to 12 questionnaires/month in base plan,
   - enforce `$150` overage above 12,
   - trigger ops escalation if contribution margin falls below `35%` on any active pilot week,
   - trigger pricing/scope review if reviewer load exceeds target for two consecutive weeks.

## Daily Operating Cadence
1. 09:00 - pipeline + active questionnaire status check.
2. 12:00 - unresolved `NEEDS_SOURCE` and rejected-answer review.
3. 17:00 - gate compliance review before any external delivery.
4. End of day - scorecard update and next-day bottleneck assignment.

## Weekly Review Cadence
1. Gate compliance: citation coverage, approval coverage, incident count.
2. Throughput: median turnaround time, review-time trend.
3. Economics: contribution margin by account, overage capture, SLA exceptions.
4. Pilot health: expansion/renewal signals and risk flags.

## Escalation Rules
- Immediate stop-ship if any material uncited answer is detected pre-send.
- 24-hour root cause review for any customer-facing quality incident.
- Pause new pilot onboarding if two consecutive weeks miss both quality and margin gates.

## Definition of Done (Cycle 003)
- At least one live questionnaire completes all 5 states with full audit artifacts.
- All exports pass citation and human-approval hard gates.
- Scorecard shows contribution margin at or above threshold for active pilot work.
