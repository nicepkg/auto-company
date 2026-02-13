# Cycle 001 Brainstorm (Role: product-norman)

## Idea Name
**QuoteClarity for Home Services**

## ICP
Owner-operators and small sales teams at home-service companies (HVAC, plumbing, roofing, electrical) with 3-30 employees, sending 20-150 estimates per month by PDF/SMS/email, and losing deals to slow or unclear customer decision-making.

## Problem
Customers struggle to understand contractor estimates (line-item PDFs, unclear scope, weak comparison between options), so they delay, ask repetitive questions, or abandon. From a Don Norman lens: the current estimate format has poor affordance (unclear next step), weak mapping (scope-to-price is hard to parse), and insufficient feedback (customer and contractor both lack clear state visibility).

## User Groups and Scenarios
1. **Estimator / Office Manager**: creates and sends a quote, needs customer response in hours not days.
2. **Homeowner**: compares options on mobile, needs confidence in what is included/excluded before paying deposit.
3. **Owner**: needs higher close rate and fewer back-and-forth clarification calls.

Primary scenario: Estimator sends a QuoteClarity link by SMS; homeowner opens one mobile page, compares 3 options (Good/Better/Best), asks one clarifying question if needed, and accepts with deposit.

## MVP in 7 Days
1. Contractor-side quote builder: title, 3 package tiers, optional add-ons, exclusions, deposit amount.
2. Customer-side mobile page with high-clarity cards and one primary action per state (`Choose`, `Ask Question`, `Approve + Pay Deposit`).
3. Basic feedback states: `Sent`, `Viewed`, `Question Asked`, `Accepted`, `Deposit Paid`.
4. Stripe checkout for deposit and SMS/email notifications.
5. Lightweight activity log per quote (single timeline).

## GTM First Channel
Manual outbound to local contractor Facebook groups + direct cold outreach to 100 contractors/week offering a 14-day pilot framed as “increase quote acceptance without changing your CRM.”

## Pricing Hypothesis
$99/month for up to 50 quotes, then $199/month up to 200 quotes. No setup fee in first 30 days to reduce adoption friction.

## Cognitive/Usability Risks
1. Choice overload if tier differences are not explicit.
2. Trust drop if exclusions or extra fees appear late in flow.
3. Mobile readability issues causing misinterpretation of scope.
4. Ambiguous status language (“approved” vs “deposit paid”) causing operational errors.

## Design Changes Aligned to Norman Principles
1. **Affordance**: large, explicit action buttons and plain-language labels (`Choose Option`, `Pay Deposit`).
2. **Mapping**: side-by-side feature comparison with visual inclusion markers so scope maps directly to price.
3. **Feedback**: immediate state confirmation for both parties after each action.
4. **Constraints**: prevent acceptance until required scope acknowledgments are checked.
5. **Progressive disclosure**: show summary first, expand full line-item detail on demand.

## Likely Usability Failures
1. Homeowner selects cheaper tier by mistake due to weak differentiation.
2. Customer assumes financing/tax is included when it is not.
3. Contractor believes a job is “closed” when only quote was viewed.

## Validation and Testing Plan (Week 1)
1. Run 5 moderated usability tests with contractors creating quotes (time-to-send and errors).
2. Run 8 homeowner tests on mobile (comprehension of included/excluded items).
3. Pilot with 3 contractors on live quotes for 7 days.
4. Success metrics: quote-view-to-accept conversion, median time to decision, clarification-message rate.
5. Failure threshold: if clarification rate does not decrease by at least 25% vs current process, revisit information architecture before scaling.

## Key Risk
Workflow inertia: contractors may resist duplicating estimates outside current tools (Jobber/Housecall Pro/ServiceTitan), limiting adoption despite clear user value.

## Next Action
Recruit 3 contractor pilot accounts this week and run a clickable prototype test focused on tier comparison comprehension before writing production code.
