# Cycle 002 (Research-Thompson) - Security Questionnaire Autopilot

## Decision
**GO (conditional).**

Condition: treat this as a **service-assisted workflow product** (outcome + SLA + defensibility), not a “platform feature race” against Vanta/Drata/Conveyor/Whistic.

## Scope And Source Set
Internal (this repo):
- Pilot contract + pricing floor: `docs/sales/cycle-003-pilot-001-order-form.md`
- Pilot workflow execution (citation + approval gates): `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`
- Unit economics and repricing rationale: `docs/cfo/cycle-002-unit-economics.md`
- Prior market validation + competitor set: `docs/research/cycle-002-market-validation.md`
- Current operational blocker (hosted persistence evidence): `docs/qa/cycle-005-hosted-supabase-persistence-execution-report.md`, `docs/operations/cycle-005-hosted-runtime-env-vars.md`

External (already captured in cycle market validation):
- Vanta questionnaire automation, Conveyor positioning, Whistic AI positioning, CSA CAIQ structure, and regulatory timing (SEC, NIS2, DORA): see `docs/research/cycle-002-market-validation.md`.

## What’s True Right Now (Facts)
- `confirmed`: There is **contracted revenue**: Pilot #1 signed **2026-02-13** for **$2,000 onboarding** + **$1,800/month** (includes 12 questionnaires; $150 overage). Source: `docs/sales/cycle-003-pilot-001-order-form.md`.
- `confirmed`: The workflow gates can pass end-to-end (ingest -> draft -> approve -> export) with **100% citation coverage** and **mandatory human approval** in shipped artifacts. Source: `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.
- `confirmed`: The “hosted persistence evidence” (Supabase-backed run/event proof for Cycle 005) is currently **blocked by missing hosted runtime env vars / base URL + prod credentials**. Source: `docs/qa/cycle-005-hosted-supabase-persistence-execution-report.md`, `docs/operations/cycle-005-hosted-runtime-env-vars.md`.

## Thompson Lens: Where Value Accrues
### Value Chain (Simplified)
1. **Enterprise buyer security team** demands evidence (questionnaires, SOC 2, policies).
2. **Vendor security team / engineering** produces answers and artifacts.
3. **Trust layer tooling** packages this into repeatable distribution:
   - Trust centers (demand aggregation for *buyers*; distribution leverage for *vendors*).
   - Compliance platforms (supply aggregation for vendors: collect evidence once, reuse everywhere).
4. **Questionnaire automation** becomes a feature inside the trust/compliance stack, because that’s where the “data exhaust” (controls, policies, audits) already lives.

Implication:
- Competing on “AI drafts answers” is structurally weak: incumbents have (a) **distribution** (existing compliance customers) and (b) **data gravity** (your evidence corpus already in their systems).

### The Small-Team Wedge That Still Works
The realistic wedge is **outcomes**, not tooling:
- **Speed**: deliver drafts in <= 24h and exports <= 48h (already contractually scoped in Pilot #1).
- **Defensibility**: citation-first answers + human approval gates (already enforced).
- **Operational reliability**: persistence evidence + audit trail (currently blocked, but solvable).

This is a classic “services-first” path: use a workflow product to reduce marginal costs while selling a deliverable that buyers already budget for (time saved + deal velocity + risk reduction).

## Competitive Dynamics (Why This Is Not Obviously Dead)
- `confirmed`: Category is validated and crowded (Vanta, Drata/SafeBase, Conveyor, Whistic). Source set summarized in `docs/research/cycle-002-market-validation.md`.
- `likely`: Incumbents will keep bundling questionnaire automation because it increases retention and expands TAM inside compliance/trust suites.
- `likely`: A narrow segment still won’t buy a full platform (cost, implementation drag, wrong stage), but will pay for **concierge speed** during active enterprise sales cycles.

ICP that fits the wedge (highest probability):
- B2B SaaS with enterprise deals in-flight, small security team, high opportunity cost of delays, and no appetite for a full GRC platform rollout.

## Business Model Fit (What Must Stay True)
Unit economics only work if pricing stays at (or above) the floor:
- `confirmed`: Repricing is required; low base subscription fails under service-assisted COGS. Source: `docs/cfo/cycle-002-unit-economics.md`.
- `confirmed`: Pilot pricing is already aligned with the viable model. Source: `docs/sales/cycle-003-pilot-001-order-form.md`.

Non-negotiables to preserve margin and trust:
- 100% citations on exports.
- mandatory human approval on exports.
- enforce questionnaire volume as the value metric (overages matter).

## Fatal Blockers And Smallest Viable Mitigation
### Blocker 1 (Operational, Near-Term): Hosted Persistence Evidence Is Blocked
Why it matters:
- You are selling “defensible answers”; without a reliable audit trail and persisted run/event history in the hosted environment, you risk a credibility gap at exactly the moment trust is on the line.

Smallest viable mitigation (do this before expanding sales claims):
1. Set hosted runtime env vars (`NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) in the actual hosting provider, redeploy, and verify with `GET /api/workflow/env-health`. Source: `docs/operations/cycle-005-hosted-runtime-env-vars.md`.
2. Run the Cycle 005 wrapper against the real hosted `BASE_URL` to generate run-id-specific DB evidence (`workflow_runs`, `workflow_events`) and append to the sales ledger. Source: `docs/qa/cycle-005-hosted-supabase-persistence-execution-report.md`.

### Blocker 2 (Strategic, Ongoing): Incumbent Distribution Advantage
Not fatal, but existential if ignored.

Mitigation:
- Position explicitly as “done-with-you / done-for-you questionnaire delivery engine” for teams that cannot justify a platform, and measure outcomes (deal cycle-time, acceptance/rework rate).
- Avoid building trust-center surface area until there’s a proven distribution channel; integrate/export into whatever the customer already uses.

## Recommendation
**GO**, with the following execution constraints:
1. **Do not scale pilots** until persistence evidence is produced in the hosted runtime (Cycle 005 evidence gate).
2. Sell the wedge: **SLA + citations + approval + export reliability**, not “AI automation.”
3. Use Pilot #1 to extract first-hand signals:
   - acceptance/rework rate,
   - turnaround time delta vs baseline,
   - what artifacts prospects actually request (and how often).

## Assumptions (Explicit)
- The pilot buyer’s willingness to pay at the floor price generalizes to at least a small cohort (not a one-off).
- Questionnaire volume is recurring enough that “per month included + overage” is a stable value metric.
- You can keep human-review time bounded (or raise overages) without breaking the customer promise.

## Confidence
- Decision (GO conditional): `likely`
- Ability to out-feature incumbents: `unlikely`
- Ability to win with services-first wedge in a narrow ICP: `likely`

