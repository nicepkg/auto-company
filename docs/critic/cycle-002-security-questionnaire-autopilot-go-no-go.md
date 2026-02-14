# Cycle 002 Critic Memo - Security Questionnaire Autopilot (Decision Update)

## Verdict
**SUPPORT (GO), conditional on clearing the hosted persistence evidence gate within 48 hours.**

If the team cannot set hosted Supabase env vars + redeploy + produce Cycle 005 DB persistence evidence quickly, treat this as an execution competence red flag and **pause all feature work** until fixed.

## What Is True Right Now (Repo Evidence)
- Paying demand exists (not just vibes): `$2,000 onboarding booked; $1,800 MRR contracted` and `1 pilot account active`. Source: `memories/consensus.md`.
- Workflow gates are already demonstrated (citations + human approval + export manifests) for pilot #1. Source: `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.
- The immediate blocker is operational, not product-market: the deployed runtime is missing `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, blocking migration/seed and DB persistence evidence generation. Sources: `memories/consensus.md`, `docs/devops/cycle-005-hosted-runtime-env-vars.md`, `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.

## Assumptions (Explicit)
- We can legally store/process customer questionnaire data in Supabase for this pilot (contract + DPA posture is acceptable).
- We control the hosting provider config for the deployed Next.js runtime that serves `/api/workflow/*` (Vercel or Cloudflare Pages).
- The required env vars can be set for the correct environment (Production vs Preview) and redeploys are not blocked by permissioning.
- The near-term differentiation is execution reliability + safety gates (not unique ML); incumbents can copy features quickly.

If any assumption is false, the recommendation changes toward **NO-GO on scaling** (not necessarily on finishing this pilot).

## Inversion: How This Fails (Concrete Scenarios)
### Failure Scenario 1: “We look amateur and lose trust”
- Cycle 005 persistence evidence remains blocked (or flaky) for days.
- Customer infers we cannot run a reliable, auditable system under deadline pressure.
- Pilot churns, and referrals dry up (the product is trust-sensitive; early reputation compounds).

Smallest viable mitigation:
- Set hosted env vars, redeploy, and prove it with a single probe: `GET <BASE_URL>/api/workflow/env-health` returning `ok=true` and both env booleans true.
- Immediately run the evidence workflow to produce `docs/devops/cycle-005-supabase-persistence-<run_id>.json` and append it to the sales ledger under `## Cycle 005 DB Persistence Evidence Log`.

### Failure Scenario 2: “We accidentally run with the wrong base URL / wrong environment”
- Evidence runner hits a static/marketing domain or a Preview environment missing secrets.
- We believe we have “proof”, but it is non-reproducible or points to the wrong system.
- Later, an enterprise buyer asks for auditability and we cannot produce consistent evidence.

Smallest viable mitigation:
- Treat `BASE_URL` selection as an evidence artifact (log the probe output + selected URL).
- Require `env-health` pass on the exact `BASE_URL` before any evidence run (no exceptions).

### Failure Scenario 3: “Data handling incident”
- Supabase keys are mishandled (leaked in logs/CI, shared across environments, or pasted into the wrong place).
- Even without an external breach, internal access sprawl or misconfiguration creates a security incident narrative.
- In this market, perceived sloppiness is fatal.

Smallest viable mitigation:
- Service-role key is only present in the hosted runtime secret store (not in client bundles, not in docs, not in plaintext logs).
- Use the existing `env-health` boolean-only probe; never print secret values.
- Restrict who can set provider env vars; keep a single owner.

## Fatal Flaw Test (As of Today)
- No paying demand: **Disproven** by contracted pilot revenue (good).
- Weak monetization path: **Still risky**. This is a workflow + service business; margins depend on reviewer time staying bounded.
- Easy replication: **High**. Assume competitors can ship “AI autofill” fast. Edge must be reliability, evidence, and service outcomes.
- Wrong timing: **Moderate**. Teams with active enterprise pipeline and frequent questionnaires have real urgency; others do not.

The closest thing to a *fatal blocker* right now is not “market” but **deployment control**. If we cannot reliably configure and prove the hosted runtime, we do not have a credible product in a compliance-adjacent domain.

## Misjudgment Checklist (Where We’re Most Likely Lying to Ourselves)
- Incentive bias: “Shipping features” feels like progress; fixing boring env plumbing feels like a distraction. In reality, plumbing is the product here.
- Tool bias: LLM output quality can distract from operational truth: audits demand durable evidence, not pretty answers.
- Social proof bias: Incumbents “adding AI” can provoke a roadmap panic. Don’t compete on checkboxes.
- Sunk cost bias: Avoid building more workflow steps until persistence evidence is done; otherwise you compound uncertainty.
- Confirmation bias: One successful pilot run can hide fragility; the next buyer cares about repeatability.

## Recommendation (Decision-Quality)
**GO, but narrow the next 48 hours to a single goal: produce and log Cycle 005 DB persistence evidence from the real hosted runtime.**

### Kill / Pause Criteria (Near-Term)
- If `env-health` cannot be made to pass on the production `BASE_URL` within 48 hours, **pause expansion** and assign a single owner to fix provider env + redeploy automation.
- If persistence evidence can be produced only via fragile, one-off manual steps, treat it as a reliability debt that blocks onboarding additional pilots.

## Smallest Viable Mitigation (Ops Checklist)
1. Set hosted runtime env vars: `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
2. Redeploy the hosted runtime.
3. Verify: `GET <BASE_URL>/api/workflow/env-health` => `ok=true` and both env booleans `true`.
4. Run Cycle 005 evidence workflow and capture: `docs/devops/cycle-005-supabase-persistence-<run_id>.json`.
5. Append entry into: `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` under `## Cycle 005 DB Persistence Evidence Log`.

