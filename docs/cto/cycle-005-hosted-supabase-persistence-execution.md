# Cycle 005 Hosted Supabase Persistence Execution (CTO-Vogels)

Date: 2026-02-13

## Objective

Unblock the hosted Security Questionnaire Autopilot workflow by:
1. Applying the Supabase migration + seed (Cycle 003 hosted workflow schema).
2. Ensuring the hosted runtime has `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
3. Running one customer-originated hosted intake against the deployed `BASE_URL`.
4. Capturing run-id-specific DB persistence evidence (`workflow_runs` + `workflow_events`) and appending it into `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`.

## Current Execution Status (This Workspace)

Blocked: no credentialed hosted environment inputs are available in this runtime.
- `NEXT_PUBLIC_SUPABASE_URL=UNSET`
- `SUPABASE_SERVICE_ROLE_KEY=UNSET`
- `SUPABASE_DB_URL=UNSET`
- Hosted `BASE_URL` is not present anywhere in-repo (previous QA metadata uses `http://localhost:3000`).

Consequence: the single-command wrapper cannot be executed end-to-end here because it must hit the deployed Next.js API and (optionally) apply SQL.

## Concrete Deliverables Shipped In-Repo (To Reduce Manual Steps / Prevent Evidence Drift)

1. **Schema/evidence drift hardening**
   - `projects/security-questionnaire-autopilot/supabase/bundles/workflow-schema-version.json`
     - Single source of truth for expected schema bundle identity + hashes.
   - `projects/security-questionnaire-autopilot/lib/supabase/workflow-repo.ts`
     - Every `workflow_runs.metadata` upsert now stamps:
       - `schema_bundle_id`, `schema_bundle_sha256`, `schema_migration_sha256`, `schema_seed_sha256`
     - This makes evidence traceable even if operators bypass Dashboard verification steps.
   - `projects/security-questionnaire-autopilot/app/api/workflow/db-evidence/route.ts`
     - Response now includes `expectedSchema` so evidence can be validated against the intended bundle.
   - `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh`
     - Preserves `expectedSchema` when normalizing hosted evidence.
     - Enforces schema match during validation via `REQUIRE_SCHEMA_MATCH=1`.
   - `projects/security-questionnaire-autopilot/scripts/validate-supabase-workflow-evidence.mjs`
     - Adds schema identity validation (strict when `REQUIRE_SCHEMA_MATCH=1`).
   - `projects/security-questionnaire-autopilot/scripts/append-supabase-evidence-to-sales-doc.mjs`
     - Appends schema identifiers from both `/api/workflow/supabase-health` and `workflow_runs.metadata` into the sales ledger entry.

2. **Automation to reduce Dashboard-only SQL applies**
   - `.github/workflows/cycle-005-supabase-apply.yml`
     - Manual `workflow_dispatch` GitHub Action that applies the SQL bundle using `SUPABASE_DB_URL` stored as a GitHub Actions secret.
     - This converts a human “paste into SQL editor” action into an auditable, repeatable, one-click deploy step.

3. **Workflow-dispatch hardening (minimal operator input)**
   - `.github/workflows/cycle-005-hosted-persistence-evidence.yml`
     - Robust `workflow_dispatch` that can run with `base_url` left empty when a repo variable is set.
     - Fails fast if the selected hosted runtime does not expose the workflow API or lacks required Supabase env vars.
   - `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`
     - Deterministic BASE_URL selection via `GET /api/workflow/env-health` (rejects marketing/static sites).
     - Candidate sources: workflow input, repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, legacy variables, and (best-effort) GitHub Deployments metadata.
   - `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-github-deployments.sh`
     - Helper to extract 2-6 candidate deployment URLs from GitHub Deployments (when the hosting integration publishes them).

## Failure Modes and Guardrails (Vogels Lens)

- “Everything fails”: schema mismatches are the dominant latent failure (tables exist but semantics drift).
  - Guardrail: `/api/workflow/supabase-health` already validates `workflow_app_meta.schema_bundle_id` by default (requires applying the shipped bundle/seed).
  - Guardrail: per-run evidence now carries schema identity in `workflow_runs.metadata` and is validated in the wrapper.
- “Wrong BASE_URL”: operator points at the wrong domain (marketing site, wrong service, stale preview).
  - Guardrail: BASE_URL is selected only by probing runtime-owned endpoints (`/api/workflow/env-health`) and enforcing required Supabase env presence.
  - Guardrail: GitHub Actions runs can pin candidates in `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` to avoid per-run manual entry.
- “You build it, you run it”: the wrapper script is the operational contract.
  - Guardrail: wrapper now fails fast if evidence schema doesn’t match the expected bundle identity.

## How To Close (Once Credentials + BASE_URL Exist)

Runbook is authoritative:
- `docs/devops/cycle-005-credentialed-supabase-apply-runbook.md`

One-command execution:
```bash
cd /home/zjohn/autocomp/auto-company

BASE_URL="https://<deployed-hosted-domain>"
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"

# If SQL was applied via Dashboard SQL Editor:
export SKIP_SUPABASE_SQL_APPLY=1

./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"
```

Expected result:
- DB evidence JSON created at `docs/devops/cycle-005-supabase-persistence-<run_id>.json`
- Sales ledger auto-appended in `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md`

## Next Action

Provide (out-of-band) the deployed hosted `BASE_URL` and confirm the target Supabase project has the bundle applied; then run `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh` from a credentialed shell to generate and append the DB evidence entry.
