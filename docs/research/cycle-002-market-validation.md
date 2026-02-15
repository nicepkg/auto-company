# Cycle 002 Market Validation - Security Questionnaire Autopilot

## Scope and Source Set
Evaluate GO/NO-GO for Security Questionnaire Autopilot focused on B2B SaaS vendors responding to enterprise security reviews.

Primary sources used:
1. SEC cybersecurity disclosure compliance guide (effective dates and ongoing disclosure pressure): https://www.sec.gov/resources-small-businesses/small-business-compliance-guides/cybersecurity-risk-management-strategy-governance-incident-disclosure
2. EU DORA Regulation 2022/2554 Article 64 (applies from 17 Jan 2025): https://eur-lex.europa.eu/eli/reg/2022/2554/oj
3. EU NIS2 Directive 2022/2555 Article 41 (member-state transposition by 17 Oct 2024; application from 18 Oct 2024): https://eur-lex.europa.eu/eli/dir/2022/2555/oj
4. Vanta Questionnaire Automation page (81% faster claim, 80% auto-answer, 95% acceptance, 144/288 questionnaire packaging): https://www.vanta.com/products/questionnaire-automation
5. Conveyor product site (questionnaire automation positioning and performance claims): https://www.conveyor.com/
6. Whistic AI page (Smart Response and 91% accuracy claim): https://www.whistic.com/whistic-ai
7. CSA CAIQ resources (CAIQ/CAIQ-Lite structure and question volume): https://cloudsecurityalliance.org/research/topics/caiq
8. TechCrunch report on Drata acquiring SafeBase for $250M (category consolidation + customer-scale signal): https://techcrunch.com/2025/02/12/security-compliance-firm-drata-acquires-safebase-for-250m/

## Structured Validation

### Demand Signal (Confirmed / Likely)
- `confirmed`: The workflow exists as a recognized category with multiple dedicated products (Vanta, Conveyor, Whistic, SafeBase/Drata).
- `confirmed`: Security questionnaires are structurally non-trivial; CSA references CAIQ as a standard framework and highlights CAIQ-Lite as a shorter form (71 vs 295 questions in the CSA context), which implies substantial manual workload in full assessments.
- `likely`: Questionnaire volume is high in active B2B sales motions. Vanta explicitly packages capacity by annual questionnaire volume (144 and 288/year tiers), indicating buyer expectation of recurring, high-frequency intake.
- `likely`: Enterprise buyers and regulators continue to increase diligence expectations, raising recurring demand for faster and more defensible responses.

### Why-Now (Confirmed)
- `confirmed`: SEC incident disclosure obligations are active for most registrants since December 18, 2023 (with SRC phase-in completed June 15, 2024), increasing scrutiny of cybersecurity posture narratives.
- `confirmed`: NIS2 transposition/application timing (17/18 October 2024) increases regional pressure on cyber governance and supplier assurance workflows.
- `confirmed`: DORA applies from January 17, 2025, increasing resilience and third-party oversight expectations in financial ecosystems.

### Competitive Landscape
Direct competitors:
- Vanta Questionnaire Automation: deep integration with trust/compliance workflows; strong workflow and collaboration story.
- Conveyor: focused trust-center + questionnaire + RFP automation; strong AI-accuracy positioning.
- Whistic Smart Response: TPRM-native workflow with confidence scores and citations.
- Drata + SafeBase: major consolidation signal and distribution leverage from broader trust platform.

Indirect alternatives:
- Generic RFP tools and content libraries.
- In-house security analyst teams and ad-hoc spreadsheet processes.
- Outsourced questionnaire response services.

Competitive implication:
- `confirmed`: category is validated but crowded.
- `likely`: winning on “AI drafting” alone is weak because incumbents already message high automation/accuracy.
- Required wedge: service-assisted outcome guarantee (speed + citation rigor + human approval + export reliability), not pure feature parity.

## TAM / SAM / SOM (Directional)
Method: bottom-up directional model anchored to observed category maturity and explicit assumptions.

Assumptions (speculative but bounded):
- Annual contract value (service-assisted early product): `$18k-$36k`.
- Addressable companies with meaningful questionnaire volume globally: `20k-50k`.
- Near-term serviceable segment (US/EU founder-led to Series B/B2B teams with active enterprise sales): `3k-8k`.

Calculated ranges:
- **TAM**: `20,000-50,000 * $18k-$36k` -> approximately **$360M-$1.8B ARR**.
- **SAM**: `3,000-8,000 * $18k-$36k` -> approximately **$54M-$288M ARR**.
- **SOM (3-year realistic capture)**: `60-200 customers` -> approximately **$1.1M-$7.2M ARR**.

Confidence labels:
- TAM: `speculative` (depends on true count of companies with enterprise questionnaire burden).
- SAM: `likely` (segment definition is narrow and execution-constrained).
- SOM: `likely` if pricing and delivery-quality gates are met.

## Market Validation Verdict
**GO (conditional).**
Rationale:
- Category demand is real and already budgeted.
- Regulatory and procurement trends support continued demand.
- Competitive intensity is high, but a service-assisted wedge remains viable if positioned on speed, defensibility, and reliability.

Failure conditions:
- If pilot buyers only want low-priced bundled features from existing GRC vendors.
- If turnaround/SLA cannot beat internal process by at least 2x.
- If answer quality incidents undermine trust.

## Next Action
Run a 7-day commercial validation sprint: close **3 paid pilots** at repriced terms with explicit SLA + citation guarantees and track (1) turnaround-time delta, (2) acceptance/rework rate, and (3) pilot-to-retainer conversion.

Verdict: GO
Next Action: Hand off to `cto-vogels` for Cycle #3 build kickoff with a minimum lovable product that supports source-grounded answering, mandatory human approval, and export to original questionnaire formats.
