# Cycle 003 Quality Risk Profile - Security Questionnaire Autopilot

## Scope Under Test
End-to-end MVP workflow:
1. Ingest evidence docs and customer questionnaires.
2. Generate source-grounded draft answers with citations.
3. Enforce mandatory human approval before export.
4. Export completed questionnaire package.

## Critical Quality Attributes
1. Citation integrity (traceable, relevant, non-stale evidence).
2. Approval integrity (no bypass, no silent post-approval mutation).
3. Export fidelity (format preserved, no answer-field corruption).
4. Turnaround performance (pilot SLA support).
5. Delivery margin protection (human review time and pricing floor enforced).

## Risk Ranking (Probability x Impact)
| Rank | Risk | Probability | Impact | Evidence / Trigger | QA Response |
|---|---|---|---|---|---|
| 1 | Uncited or weakly cited answer exported | High | Critical | Missing citation metadata or irrelevant source spans | Stop-ship gate + blocking check at export API |
| 2 | Human approval bypass | Medium | Critical | Export succeeds without `approved_by` + timestamp | Stop-ship gate + workflow state-machine tests |
| 3 | Post-approval edits exported without re-approval | Medium | High | Answer changes after approval but state stays approved | Immutable approval snapshot + mutation-reset check |
| 4 | Questionnaire parse mismatch causes wrong field mapping | High | High | XLSX/DOCX irregular layouts, merged cells | Parser fuzz and golden-file regression checks |
| 5 | Export package corrupts original structure | Medium | High | Missing tabs, broken formulas, shifted columns | Format parity checks + round-trip tests |
| 6 | Review effort exceeds profitable threshold | High | High | Median review time >15 min/questionnaire for 2 weeks | Margin gate and pilot scope throttling |
| 7 | High-risk controls accepted with low confidence | Medium | High | Auth/encryption/incident-response answers with low confidence | Mandatory senior reviewer path for high-risk tags |
| 8 | Stale evidence used in drafts | Medium | Medium | Citation points to old policy version | Evidence freshness checks + warning banner |

## Mandatory Release Gates (Non-Negotiable)
1. `No uncited answers`: 100% of non-empty draft/exported answers must include at least one citation with document ID, section/chunk ID, and evidence text span.
2. `Human approval required`: 100% of exported answers must have explicit human approval event (`user_id`, timestamp, decision).
3. `Margin protection`:
   - No signed pilot below `$2,000 onboarding + $1,800/mo + $150 overage`.
   - Median reviewer touch time <=15 minutes per questionnaire (rolling 2-week window).
   - If threshold breached for 2 consecutive weeks, pause onboarding of new pilots.

## Stop-Ship / Pause Rules
1. Stop-ship immediately if any export includes uncited answer content.
2. Stop-ship immediately if export path can be executed without approval records.
3. Pause expansion if contribution margin per pilot account is negative after 5 paid pilots.
4. Pause expansion if material answer incident reaches external buyer without pre-submission catch.

## Exit Criteria For Cycle 003 QA Sign-Off
1. All gate checks pass in CI and staging for 3 consecutive runs.
2. At least 10 golden questionnaires pass parse -> draft -> approve -> export round-trip.
3. High-risk control sample set (minimum 50 Q/A pairs) shows 100% citation presence and 0 approval bypass.
4. Pilot operations dashboard includes pricing-floor, review-time, and overage metrics.

## Risk Owner Mapping
1. Citation/approval gate integrity: QA + Fullstack.
2. Parse/export fidelity: Fullstack + QA.
3. Margin gate observability: Operations + CFO + QA.
4. Incident response for answer-quality defects: QA lead + CTO.
