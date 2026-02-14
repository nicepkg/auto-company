# Cycle 002 CFO GO/NO-GO - Security Questionnaire Autopilot (SQA)

## Financial Conclusion (Decision)
**GO (conditional).** We already have paying traction at value-based pricing (`$2,000` onboarding + `$1,800/mo`), so the business case is strong *if* we unblock production-grade persistence immediately and confirm true variable cost (including human time) stays within the margin guardrails.

If we cannot produce Supabase-backed persistence evidence in the hosted runtime within `48 hours`, treat this as a **NO-GO for scaling sales/onboarding** (continue only as an internal prototype) because we will be unable to credibly support auditability and reliability expectations for security/compliance workflows.

## Confirmed Commercial Facts (From Repo Artifacts)
- **Pilot #1 (Northstar SaaS)**: `Closed Won -> Active Pilot`. (`docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`)
- **Contracted revenue**:
  - `$2,000` onboarding booked/paid. (`memories/consensus.md`, `docs/sales/cycle-003-pipeline-tracker.csv`)
  - `$1,800` MRR contracted. (`memories/consensus.md`, `docs/sales/cycle-003-pilot-001-order-form.md`)
- **Pilot term**: `3 months`; onboarding due at signature; month 1 due at kickoff. (`docs/sales/cycle-003-pilot-001-order-form.md`)
- **Package**: includes `12 questionnaires/month` + `$150` overage per questionnaire above 12. (`docs/sales/cycle-003-pilot-001-order-form.md`)

### Contract Value (Minimum)
- Pilot minimum contract value (excludes overages): `2,000 + 1,800 * 3 = $7,400`

## Unit Economics Snapshot (Pilot Pricing)
### What we have (confirmed in current artifacts)
- Margin validator assumption for Pilot #1 scenario:
  - Expected questionnaires: `14/month`
  - Estimated COGS: `$35 / questionnaire`
  - Projected revenue at 14 questionnaires: `$2,100/month`
  - Projected gross margin: `76.67%` (passes 70% floor). (`docs/sales/cycle-003-pilot-001-margin-validation-pass.json`)

### CFO interpretation (assumptions called out)
- **Assumption A1 (critical)**: `$35/questionnaire` includes *all* variable delivery costs that scale with volume:
  - LLM/API costs
  - storage/compute
  - and any human review time
- If `$35` excludes human labor, then the “gross margin” is overstated and we risk selling unprofitable volume at `$1,800/mo`.

## Primary Risks (Ordered by Business Impact)
### 1) Retention and cash risk (near-term)
- Month-1 subscription is due at kickoff; if kickoff slips or trust is reduced, cash collection and month-2 continuation are at risk. (`docs/sales/cycle-003-pilot-001-order-form.md`)

### 2) Operational credibility risk (fatal for enterprise motion)
- Current ops blocker: hosted runtime missing `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, blocking **Cycle 005 DB persistence evidence**. (`memories/consensus.md`, `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`)
- Without durable run/event persistence, we can still generate exports, but we cannot credibly claim auditability for a security workflow (and we lose the ability to debug/measure delivery at scale).

### 3) Margin erosion risk (mid-term)
- The product is a “service-assisted workflow.” If review time drifts up, margin can collapse quickly unless we:
  - enforce overages/change orders, and
  - measure real delivery time per questionnaire (not just modeled cost).

## Fatal Blockers and Smallest Viable Mitigations
### Fatal blocker B1: No hosted Supabase persistence (Cycle 005 evidence blocked)
Smallest viable mitigation:
1. Set hosting provider env vars: `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
2. Redeploy hosted runtime.
3. Re-run the Cycle 005 evidence collector to append `workflow_runs` + `workflow_events` evidence to sales ledger. (`memories/consensus.md`)

### Fatal blocker B2 (financial): Unvalidated “true” COGS including labor
Smallest viable mitigation:
- For the next 5 questionnaires delivered, record:
  - reviewer minutes (actual),
  - LLM/API cost (actual),
  - and compute `COGS/questionnaire` and gross margin vs the 70% floor.
- If fully-loaded variable cost exceeds `~$45/questionnaire` at the current pricing/overage structure, we will breach the 70% gross margin floor at typical volumes (see `docs/cfo/cycle-002-sqa-unit-econ-scenarios.csv`). (Assumes costs scale primarily per questionnaire and there is no additional material per-account variable cost.)

## GO Conditions (What must be true to keep investing and selling)
1. **Persistence proof**: Cycle 005 DB persistence evidence successfully produced from hosted runtime by `2026-02-15` (48h from current consensus timestamp `2026-02-13 14:57:38 PST`).
2. **Cash discipline**: collect month-1 subscription at kickoff (no delivery without payment terms honored).
3. **Margin discipline**: confirm fully-loaded variable cost stays below threshold to maintain `>=70%` gross margin at the contracted package.

## Recommendation
- **GO** on SQA as the primary company project, but **pause scaling sales onboarding** until Supabase persistence evidence is attached and fully-loaded COGS is validated with real delivery data (not modeled-only).
- Maintain price floor; do not discount base MRR (discounts should be offered, if ever, via onboarding concessions only, and only if margin is measured healthy).
