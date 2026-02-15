# Cycle 003 Test Strategy And Exploratory Charters

## 1) Targeted Test Strategy

### Test Missions
1. Prevent uncited answers from reaching export.
2. Prove approval gate cannot be bypassed or invalidated.
3. Verify parse/export reliability across messy real-world formats.
4. Contain delivery risk by monitoring review-time and rework signals.

### Balanced Checking vs Testing
1. Automated checks for deterministic gates (`citation`, `approval`, `export validity`).
2. Exploratory testing sessions for ambiguous behavior (`question interpretation`, `citation relevance`, `weird file formats`).
3. Human risk review for high-impact controls (`encryption`, `access control`, `incident response`).

### Test Layers (Cycle 003 Minimum)
| Layer | Goal | Required Scope |
|---|---|---|
| Unit | Core policy logic | Citation-required validator, approval state transitions, export eligibility rules |
| Integration | Service contracts | Ingest parser -> draft generation -> approval storage -> export API |
| E2E | Business-critical path | Upload docs + questionnaire, generate drafts, approve all, export package |
| Exploratory | Unknown risk discovery | 90-minute sessions on parser edge cases, citation relevance, and workflow abuse |

## 2) Must-Pass Check Inventory

| ID | Check | Gate |
|---|---|---|
| CHK-001 | Export rejected if any answer has `citations.length == 0` | No uncited answers |
| CHK-002 | Export rejected if any answer status != `approved` | Human approval required |
| CHK-003 | Any answer edit after approval resets status to `needs_review` | Human approval required |
| CHK-004 | Citation must reference existing ingested doc/version/chunk | No uncited answers |
| CHK-005 | Parse preserves question count and stable question IDs | Export reliability |
| CHK-006 | Export preserves original sheet/section ordering | Export reliability |
| CHK-007 | Pricing API rejects contracts below floor | Margin protection |
| CHK-008 | Ops metrics job emits review-time and margin signals daily | Margin protection |

## 3) Exploratory Test Charters (James Bach Style)

### Charter 1: Citation Relevance Under Ambiguity
- Mission: Probe whether citations are merely present vs substantively supporting the answer.
- Data: Conflicting policy versions, vague questions, duplicated controls.
- Oracles: Relevance judged by traceability to exact requirement language; stale sources flagged.

### Charter 2: Approval Workflow Abuse
- Mission: Attempt bypass via direct API calls, race conditions, and stale UI state.
- Data: Multiple reviewers, concurrent edits, session timeout/re-auth.
- Oracles: Export must remain blocked unless latest content has explicit approval.

### Charter 3: Parse Robustness for Real Customer Files
- Mission: Discover parser failures on messy XLSX/DOCX/CSV structures.
- Data: Merged cells, hidden sheets, multiline prompts, encoding issues.
- Oracles: No silent drop/merge of questions; parser warnings explicit.

### Charter 4: High-Risk Control Accuracy
- Mission: Stress-test auth/encryption/incident-response answers.
- Data: 50-question curated high-risk set with known expected evidence.
- Oracles: Zero uncited outputs; low-confidence answers routed for senior review.

### Charter 5: Export Fidelity
- Mission: Validate that exported artifacts remain usable in buyer workflows.
- Data: Source templates from 3 distinct enterprise questionnaire formats.
- Oracles: Structure/format parity, no broken mandatory fields.

### Charter 6: Margin Failure Simulation
- Mission: Simulate complex questionnaires to evaluate reviewer-time blowups.
- Data: Long questionnaires, repeated conditional sections, weak source docs.
- Oracles: Review-time breaches trigger alerts and onboarding throttle.

## 4) Concrete Edge And Boundary Scenarios

### Ingest
1. Empty upload.
2. Unsupported mime type disguised as `.xlsx`.
3. Extremely large file (>50MB).
4. Duplicate document version IDs.
5. Password-protected spreadsheet.
6. OCR-noisy PDF policy text.

### Drafting And Citations
1. Question has no matching evidence in corpus.
2. Multiple conflicting evidence snippets.
3. Citation points to deleted document version.
4. Citation points to wrong tenant/account.
5. Question asks binary answer but model returns narrative.
6. Confidence low but status incorrectly set to ready.

### Approval
1. Approver role missing permission.
2. Approver edits then approves in stale browser tab.
3. Two approvers race; one rejects while one approves.
4. Approval event stored without user identity.
5. Approved answer later edited through bulk action.

### Export
1. Partial approval set (99% approved).
2. Source questionnaire contains formulas/macros.
3. Unicode and special characters in answers.
4. Hidden tabs in workbook.
5. Export retries after transient storage failure.

### Margin And Commercial
1. Pilot contract submitted below price floor.
2. Overage billed below `$150`.
3. Review-time telemetry missing for 24 hours.
4. Complex pilot with >12 questionnaires without overage trigger.
5. Reviewer effort spikes but onboarding remains open.

## 5) Automation Scope And Tools
1. API and policy checks: `pytest` or `vitest` for gate validators and workflow state machine.
2. E2E smoke: `Playwright` for upload -> draft -> approve -> export flow.
3. Contract tests: parser/export golden files with snapshot diff for questionnaire fidelity.
4. Scheduled ops checks: daily job validates pricing floor, review-time metrics, and overage policy.

## Execution Cadence (Cycle 003)
1. Pre-merge: CHK-001/002/003/004/007 blocking checks.
2. Daily: CHK-005/006 integration suite + ops metrics assertion.
3. Pre-pilot release: full E2E + exploratory charters 1/2/3/5.
4. Weekly quality review: incidents, rework rate, reviewer-time trend, gate violations.
