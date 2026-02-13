# Cycle 003 Sales Model, Funnel, and KPI Plan - Security Questionnaire Autopilot

## 1) Best-Fit Sales Model
**Model choice:** `service-assisted, low-touch + founder-led close` for initial pilots.

Why this fits current state:
- ACV at pilot terms is meaningful (`$2,000 onboarding + $1,800/mo`), so pure self-serve is too risky before proof.
- Mandatory human approval + citation QA creates implementation and trust work that needs assisted onboarding.
- Design-partner motion requires fast feedback loops, not automated high-volume pipeline yet.

Role specialization for this cycle:
- Prospecting: founder + SDR-style outbound blocks (daily).
- Closing: founder-led calls with a fixed pilot offer and legal guardrails.
- Success: onboarding + weekly ROI checkpoint to protect expansion and referrals.

## 2) Funnel Stages and Conversion Points

### Stage Definitions
1. `Target Account` -> ICP-matched SaaS company with active enterprise pipeline.
2. `Contacted` -> personalized outreach sent with clear pain/value hook.
3. `Qualified Conversation` -> live call completed and pain confirmed.
4. `Sales Qualified Opportunity (SQO)` -> meets all qualification gates below.
5. `Pilot Proposal Sent` -> proposal with non-discounted pilot pricing and hard QA terms.
6. `Closed Won - Pilot` -> onboarding fee paid and kickoff scheduled.
7. `Active Pilot` -> first questionnaire delivered through approval workflow.
8. `Retainer` -> month-2 continuation at `>= $1,800/mo`.

### Qualification Gates (must pass all)
- At least `8 questionnaires/quarter` currently or forecasted.
- Has a named owner for security questionnaire workflow.
- Agrees in principle to human final approval checkpoint.
- Accepts pricing floor with no discount below:
  - `$2,000 onboarding`
  - `$1,800/mo` includes 12 questionnaires
  - `$150` overage per additional questionnaire

### Pipeline Math to Close 3 Pilots This Cycle
- `100` targeted accounts total
- `35` meaningful replies / intro acceptances (`35%` blended warm+cold)
- `18` qualified conversations (`51%` of replies)
- `9` SQOs (`50%` of conversations)
- `6` proposals (`67%` of SQOs)
- `3` closed pilots (`50%` proposal close rate)

## 3) Concrete Acquisition Channels (Cycle 003)
1. Founder/investor/operator warm intros:
   - Ask each founder/investor contact for `2` intros to B2B SaaS leaders handling security reviews.
   - Goal: `20` warm targets, `8` conversations.
2. Persona-specific outbound (email + LinkedIn):
   - Primary titles: `Head of Security`, `GRC Lead`, `VP Engineering`, `CTO` at 20-500 employee SaaS companies.
   - Goal: `80` outbound targets, `10` conversations.
3. Compliance partner referrals:
   - Reach `5` boutique SOC2/ISO consultancies for referral swaps.
   - Goal: `3` partner-sourced conversations this cycle.

## 4) Trackable KPIs and Hard Gates

### Input KPIs (daily/weekly)
- New targeted accounts/week: `>= 50`
- Outreach attempts/week: `>= 120`
- Follow-ups/contact: `>= 3`
- Discovery calls/week: `>= 6`

### Process KPIs (funnel)
- Reply/acceptance rate: `>= 25%` blended
- Contacted -> qualified conversation: `>= 15%`
- Qualified conversation -> SQO: `>= 45%`
- Proposal -> closed pilot: `>= 40%`
- Closed pilot -> paid month-2 retainer: `>= 67%` (2 of first 3)

### Output KPIs (revenue/economics)
- New onboarding revenue this cycle: `>= $6,000`
- New MRR booked this cycle: `>= $5,400`
- Contribution margin on pilot cohort: `>= 35%`
- CAC payback target: `< 4 months`

### Non-Negotiable Product/Delivery Gates (sales-enforced)
- `NO UNCITED ANSWERS`: every answer must include source reference before handoff.
- `HUMAN APPROVAL REQUIRED`: no customer submission without explicit human approver sign-off.
- `MARGIN PROTECTION`: reviewer time target `<= 15 minutes/questionnaire`; if breached for 2 consecutive weeks, pause discount/expansion and raise scope controls or pricing.

## 5) Pricing and Package Adjustments (for Pilot Offer)
Package for cycle-003 pilots:
- Setup: `$2,000` one-time onboarding
- Subscription: `$1,800/mo` includes `12 questionnaires/month`
- Overage: `$150/questionnaire`
- Billing terms: onboarding due at signature; first month due at kickoff
- Contract term: 3-month design-partner period, then renewal at standard plan

Allowed flexibility (without floor erosion):
- Can offer faster kickoff SLA or weekly executive review.
- Can add one-time migration support.
- Cannot reduce onboarding fee, monthly base, or overage rate.

## Exact Files To Create/Modify For MVP Handoff (Sales Requirements)
These are required for sales to confidently sell and enforce gates:
1. `projects/security-questionnaire-autopilot/app/(dashboard)/questionnaires/[id]/draft.tsx`
2. `projects/security-questionnaire-autopilot/app/(dashboard)/questionnaires/[id]/approval.tsx`
3. `projects/security-questionnaire-autopilot/components/citations/citation-badge.tsx`
4. `projects/security-questionnaire-autopilot/components/approval/approval-gate.tsx`
5. `projects/security-questionnaire-autopilot/lib/workflow/gates.ts`
6. `projects/security-questionnaire-autopilot/lib/export/export-package.ts`
7. `projects/security-questionnaire-autopilot/supabase/migrations/20260213_workflow_tables.sql`
8. `projects/security-questionnaire-autopilot/docs/mvp-acceptance-criteria.md`

Minimum acceptance criteria for handoff:
- Draft cannot move to approval queue unless citation coverage is `100%`.
- Export action is disabled until human approver signs off.
- Export package includes answers, citation map, approver identity, and timestamp.

## Next Action
Execute the 14-day pilot sprint in `docs/sales/cycle-003-design-partner-pilot-sprint.md` and open 100 target accounts in the tracker immediately.
