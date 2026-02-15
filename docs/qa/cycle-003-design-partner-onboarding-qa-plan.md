# Cycle 003 Design-Partner Onboarding QA Plan

## Objective
Onboard 3 paid design-partner pilots this cycle without violating quality or margin gates.

Pricing floor (mandatory):
- `$2,000` onboarding
- `$1,800/mo` includes 12 questionnaires
- `$150` overage per additional questionnaire

## Pilot Admission Criteria (Quality + Commercial)
1. Prospect confirms active questionnaire volume (target: >=12/month or clear near-term pipeline).
2. Prospect agrees to mandatory human approval checkpoint before any submission.
3. Prospect accepts citation-first deliverable format and audit log retention.
4. Contract uses exact pricing floor with no exceptions.
5. Account has at least baseline evidence corpus (SOC 2/policies/past responses) at kickoff.

## Concrete Actions To Close 3 Paid Pilots

### Action Set A: Qualification and Deal Controls (Day 1-3)
1. Build a 15-account target list matching ICP and active enterprise deal motion.
2. Run discovery call script with 5 qualifiers:
   - Questionnaire backlog
   - Deal-stage urgency
   - Existing process turnaround time
   - Document readiness
   - Budget owner and signature path
3. Reject prospects failing pricing-floor or evidence-readiness criteria.

### Action Set B: Paid Onboarding Conversion (Day 2-6)
1. Offer fixed-scope paid pilot SOW: one live questionnaire completed in 48 hours.
2. Require onboarding invoice payment before production work starts.
3. Include explicit clauses:
   - No autonomous submission
   - Customer final approval required
   - Citation coverage requirement for every answer

### Action Set C: Delivery Quality Demonstration (Day 4-10)
1. Run first questionnaire through full gated workflow.
2. Deliver export package with:
   - Completed questionnaire
   - Citation appendix
   - Approval log
   - Open-risk list (if evidence gaps remain)
3. Conduct 30-minute readout with buyer-facing owner to confirm usability.

## Pilot Delivery SLA + QA Gates
1. Turnaround: first pass draft within 24 hours; approved export within 48 hours.
2. Citation coverage: 100% for non-empty answers.
3. Approval coverage: 100% for exported answers.
4. Rework threshold: <=20% answer-level rework after customer review.
5. Incident threshold: 0 material uncited errors in submitted package.

## Margin Protection Controls
1. Daily reviewer-time tracking by questionnaire and account.
2. Alert when median reviewer time exceeds 15 minutes/questionnaire (rolling 2 weeks).
3. Auto-flag account for pricing/scope review if:
   - >12 questionnaires/month with no overage billing, or
   - repeated low-quality customer evidence causes >25% extra review effort.
4. Freeze new pilot onboarding when margin gate breaches for 2 consecutive weeks.

## Pilot Quality Scorecard (Per Account)
| Metric | Target | Fail Condition |
|---|---|---|
| Paid onboarding collected | Yes | Work started before payment |
| Citation coverage | 100% | Any uncited exported answer |
| Approval coverage | 100% | Any export without approver event |
| Median turnaround | <=48h | >72h on live pilot |
| Rework rate | <=20% | >35% for two consecutive questionnaires |
| Reviewer effort trend | Downward by week 2 | Upward trend and margin erosion |

## Defect Reporting Standard (For Pilot Incidents)
1. One-line title.
2. Environment/account and questionnaire ID.
3. Exact reproduction steps.
4. Expected vs actual behavior.
5. Severity classification (`Critical`, `High`, `Medium`, `Low`).
6. Customer-impact statement and containment action.

## Go/No-Go For Pilot Expansion
1. GO: 3 paid pilots onboarded, zero critical uncited/approval incidents, margin gate green.
2. NO-GO: any critical gate breach or persistent negative contribution margin after first 5 pilots.
