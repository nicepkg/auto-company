# Cycle 003 Pilot #1 Order Form (Floor-Priced)

## Account
- Account alias: `Pilot #1 - Northstar SaaS`
- Primary buyer role: `Head of Security`
- Deal owner: `sales-ross`
- Contract status: `Signed`
- Signature date: `2026-02-13`

## Commercial Terms (Locked)
- Onboarding fee (one-time): `$2,000`
- Subscription fee: `$1,800/month`
- Included volume: `12 questionnaires/month`
- Overage: `$150` per questionnaire above 12/month
- Pilot term: `3 months`
- Billing: onboarding due at signature; month 1 due at kickoff

## Hard Gates (Contractual)
1. Citation gate:
   - Every exported answer must contain at least one citation mapped to stored source evidence.
2. Human approval gate:
   - Customer-named reviewer must approve each question before export.
   - Autonomous submission is not allowed.
3. Pricing floor + margin gate:
   - Pricing cannot go below floor terms above.
   - Margin validation must pass before onboarding and for each expansion quote.

## Named Pilot Roles
- Customer approver: `Pilot One Reviewer`
- Internal delivery owner: `operations`
- Internal commercial owner: `sales-ross`

## Pilot #1 Kickoff Scope
- Live workflow path required for first delivery:
  - `ingest -> draft -> approve -> export`
- First delivery SLA:
  - Draft within `<= 24h` after complete intake.
  - Export package within `<= 48h` after reviewer decisions are complete.

## Acceptance for Month-2 Continuation
- `100%` citation coverage on exports.
- `100%` approval coverage on exports.
- Weekly contribution margin remains `>= 35%`.

## Next Action
Run customer kickoff on `2026-02-14` and capture the hosted workflow run ID in the weekly commercial scorecard.
