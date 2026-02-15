# Cycle 003 Operations Brief - Security Questionnaire Autopilot

## Skill Context Used
- `micro-saas-launcher`: fast MVP-to-revenue execution with high-touch early users.
- `financial-unit-economics`: enforce pricing floor and contribution-margin gates.

## 1) Product Stage Diagnosis
**Stage: pre-PMF (paid validation phase).**

Why:
- Product value is clear, but repeatable retention and referral are not yet proven.
- Delivery still depends on high-touch human review.
- We have a pricing model that works on paper; now we must prove it with paid pilots.

## 2) Top 3 Operating Priorities (This Cycle)
1. **Run one complete gated production path** from ingest to export with explicit enforcement:
   - zero uncited answers exported,
   - 100% human approval coverage before export,
   - margin guardrail checks logged per questionnaire.
2. **Close 3 paid design-partner pilots** at non-negotiable floor pricing:
   - `$2,000 onboarding + $1,800/mo` (includes 12 questionnaires),
   - `$150` overage per additional questionnaire.
3. **Protect delivery economics from day 1**:
   - reviewer effort and rework tracked per questionnaire,
   - halt custom scope that breaks contribution margin.

## 3) Measurable Weekly Goals
- `3/3` signed paid pilots at floor pricing (no discounts below floor).
- `100%` citation coverage on every exported answer package.
- `100%` human approval coverage on every exported package.
- `<=48 hours` median upload-to-approved-export turnaround.
- `<=15 minutes` median reviewer time per questionnaire item set (or equivalent section workload bucket).
- `>=35%` contribution margin on each pilot account in-week.
- `0` material uncited or unapproved answers delivered externally.

## 4) Common Growth Traps to Avoid
- Chasing top-of-funnel volume before proving repeatable paid conversion and delivery quality.
- Discounting below pricing floor to "buy logos" and destroying margin discipline.
- Marketing as autonomous completion instead of assistive + human-verified workflow.
- Accepting custom scope without charging overage or adjusting SLA.
- Ignoring retention signals while celebrating initial pilot signings.

## 5) Concrete Execution Actions
1. Build and use the runbook in `docs/operations/cycle-003-workflow-runbook.md` for every live questionnaire.
2. Run founder-led outbound to a focused list of 30 ICP accounts (active enterprise deals, high questionnaire load).
3. Hold 12 qualification calls this cycle and issue 6 paid-pilot proposals using fixed pricing + SLA terms.
4. Require onboarding invoice paid before first live questionnaire intake.
5. Apply gate policy:
   - block export if any answer has zero citations,
   - block export if any answer lacks explicit reviewer decision,
   - block expansion if account-level contribution margin <35% for two consecutive weeks.
6. Use the scorecard `docs/operations/cycle-003-weekly-scorecard.csv` in daily standup and weekly review.

## Next Action
Start Day-1 execution: run outreach + schedule qualification calls, while CTO/fullstack implement the exact file map in `docs/operations/cycle-003-engineering-file-map.md`.
