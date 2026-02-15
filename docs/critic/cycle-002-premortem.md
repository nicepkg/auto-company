# Cycle 002 Pre-Mortem - Security Questionnaire Autopilot

## Verdict
**Support (conditional GO).**
Proceed only as a service-assisted workflow with strict accuracy, liability, and unit-economics gates. Do not market as fully autonomous completion.

## The Plan
Launch an AI-assisted security questionnaire completion workflow for B2B SaaS vendors responding to enterprise security reviews. Initial posture is service-assisted (human approval + citation guardrails), with success defined by:
- Faster questionnaire turnaround (target: 50%+ cycle-time reduction)
- Higher submission quality (target: <2% material error rate)
- Clear customer ROI (target: savings exceed fee within first 2 questionnaires)
- Repeatable delivery economics (target: positive contribution margin at pilot pricing)

## Time Jump
"It is February 2027. This initiative failed."
- Customers stopped renewing after a few pilots.
- One materially incorrect answer reached a buyer, triggered an escalation, and references dried up.
- Delivery stayed manual-heavy, margins never improved, and better-funded compliance vendors bundled similar functionality.

## What Went Wrong

| Category | Failure Mode | How It Played Out |
|----------|--------------|-------------------|
| Technical | Hallucinated or stale answers passed review | A few high-risk questions were answered from outdated docs; one customer lost trust with a strategic prospect and churned. |
| Execution | Human review bottleneck | Throughput depended on senior reviewers; SLA slipped during peak RFP weeks; customers reverted to internal teams. |
| Assumptions | "Pain = budget" assumption was wrong | Security/IT teams had pain, but budget ownership sat elsewhere; deal cycles dragged and pilots stalled in procurement. |
| External | Incumbent bundle pressure | Existing GRC/trust-center vendors added questionnaire automation as a low-priced add-on, compressing willingness to pay. |
| People | Founder-led delivery overload | Early wins required heavy founder involvement; quality dropped when delegated; process quality was not codified soon enough. |
| Technical | Weak source-of-truth hygiene | Customer policies and evidence were fragmented across docs, wikis, and tickets; model output quality was capped by poor inputs. |
| Legal/Risk | Liability ambiguity | Contract language did not clearly allocate responsibility for final answers; one dispute consumed time and damaged sales momentum. |
| GTM | Narrow channel dependency | Pipeline relied on warm founder network and did not scale; CAC climbed once warm intros were exhausted. |
| Economics | Manual effort masked poor margins | Service layer looked strong in pilots but required too many analyst hours per questionnaire to sustain at target pricing. |
| Timing | Wrong maturity window for SMB-mid market | Smaller SaaS teams had too few questionnaires to justify recurring spend; enterprise buyers preferred established vendors. |

## Risk Prioritization

| Failure Mode | Likelihood | Impact | Priority |
|--------------|------------|--------|----------|
| Accuracy failure leading to customer trust loss | High | High | 1 |
| Manual-review bottleneck destroys unit economics | High | High | 2 |
| Incumbent replication/bundling | Medium | High | 3 |
| Budget-owner mismatch elongates sales cycle | Medium | High | 4 |
| Poor customer knowledge base quality | High | Medium | 5 |
| Liability dispute due to unclear accountability | Medium | High | 6 |
| Channel saturation and rising CAC | Medium | Medium | 7 |
| Founder dependency and process fragility | Medium | Medium | 8 |
| Low questionnaire frequency in target segment | Medium | Medium | 9 |
| Integration friction across formats/workflows | Medium | Medium | 10 |

## Top 3 Risks and Mitigations

### 1) Accuracy failure leading to trust collapse
- **Risk:** Wrong or unsupported answers create customer revenue and reputational damage.
- **Early Warning Signs:**
  - Citation coverage drops below 95%
  - Increasing reviewer overrides on high-risk controls
  - Customer asks for repeated rework after submission
- **Prevention:**
  - Hard policy: no answer without source citation
  - Risk-tier questions (auth, encryption, incident response) require senior reviewer sign-off
  - Versioned evidence library per customer with freshness checks
- **Mitigation:**
  - Incident playbook: freeze automation, perform root-cause review in 24h, issue corrected package
  - Contractual limitation and explicit customer final-approval checkpoint
- **Owner:** Head of Delivery / Security QA Lead

### 2) Manual bottleneck kills margin
- **Risk:** Human-in-loop remains too heavy, preventing profitable scale.
- **Early Warning Signs:**
  - Review time >90 minutes per questionnaire section after month 2
  - Gross margin below target for 2 consecutive months
  - Missed SLAs in peak periods
- **Prevention:**
  - Constrain initial scope to top 20 recurring controls
  - Standardized answer library and retrieval templates
  - Weekly ops review of time-per-task with explicit automation backlog
- **Mitigation:**
  - Raise price for high-complexity questionnaires
  - Add capacity buffer (contract reviewers) for seasonal surges
  - Pause expansion until contribution margin threshold is met
- **Owner:** Operations Lead + CFO

### 3) Incumbent bundling compresses pricing power
- **Risk:** Customers buy this feature inside existing compliance stack at lower incremental cost.
- **Early Warning Signs:**
  - Win/loss notes cite "already included in current platform"
  - Discount pressure increases >20%
  - Pilot-to-paid conversion declines
- **Prevention:**
  - Differentiate on speed-to-submission and reviewer-grade evidence mapping, not generic "AI autofill"
  - Target customers with immediate backlog and active deals where time value is explicit
  - Build workflow integrations incumbents neglect (questionnaire-specific ops, escalation paths)
- **Mitigation:**
  - Move upmarket to higher-volume teams with acute pain
  - Reposition as service + outcome guarantee instead of seat-based software
- **Owner:** CEO + GTM Lead

## Inversion Checklist
1. **Can this be simpler?** Yes: start with assisted completion for a narrow control set, not full automation.
2. **Real problem or imagined?** Real. Questionnaire delays directly block enterprise revenue.
3. **Disconfirming evidence?** Some teams solve with internal SMEs and existing trust-center tooling; not all pain converts to spend.
4. **Worst case survivable?** Only if contracts limit liability and first incidents are tightly contained.
5. **If copied tomorrow, do we keep edge?** Only via service quality, SLA reliability, and deep workflow execution.
6. **Regret in one year?** Yes if we overbuild software before proving repeatable paid demand and margin.

## Misjudgment Checklist
- **Incentive bias:** Team may overstate automation readiness to signal "AI leverage" and win deals.
- **Tool bias:** LLM capability can be mistaken for end-to-end solution quality.
- **Social proof bias:** Competitor announcements can push premature roadmap expansion.
- **Sunk cost bias:** Early integration work may trap us in low-margin accounts.
- **Confirmation bias:** Positive pilot anecdotes may hide silent churn risk.

## Fatal Flaw Test
- **No paying demand:** Not yet disproven; must validate with paid pilots (not LOIs).
- **Weak monetization path:** Risky unless review time per questionnaire falls under target.
- **Easy replication:** High; defensibility must come from delivery quality and embedded workflow.
- **Wrong timing window:** Moderate risk in SMB; lower risk in teams with active enterprise pipeline.

## Pre-Mortem Insights
- The existential risk is not model quality alone; it is liability + trust under real customer deadlines.
- This is operationally a "security-delivery business" first, software second.
- Scale should be gated by measured accuracy and margin, not feature completeness.

## Revised Confidence
- **Current confidence:** 0.61 (moderate).
- **What raises confidence to >0.75:**
  1. Five paid pilots with zero material answer incidents.
  2. Median turnaround time reduced by >=50% versus customer baseline.
  3. Contribution margin >=35% at pilot pricing with documented reviewer-time trend down.

## Decision
**GO (conditional).**
Proceed with a tightly scoped, service-assisted MVP and explicit kill criteria:
- Kill if any material uncited error reaches customer buyer-side without prior disclosure.
- Kill/pause expansion if contribution margin stays negative after first 5 paid pilots.
- Kill/pivot segment if pilot-to-paid conversion is <30% after 15 qualified opportunities.
