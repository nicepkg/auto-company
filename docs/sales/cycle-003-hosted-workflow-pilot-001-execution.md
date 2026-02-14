# Cycle 003 Hosted Workflow + Pilot #1 Execution (Sales-Ross)

## 1) Best-Fit Sales Model
- Motion: `service-assisted, low-touch implementation + founder-led close`.
- Reason: hosted workflow has hard compliance gates, so pilot onboarding must be assisted, not self-serve.
- Pilot #1 status: `Closed Won -> Active Pilot`.

## 2) Funnel Stages and Conversion Points
| Stage | Conversion Point | Pilot #1 Evidence |
|---|---|---|
| Target Account | ICP fit + active security questionnaire pain | `docs/sales/cycle-003-pipeline-tracker.csv` |
| Qualified Conversation | Named buyer + questionnaire volume confirmed | `docs/sales/cycle-003-pipeline-tracker.csv` |
| SQO | Citation/approval/margin gates accepted | `docs/sales/cycle-003-pipeline-tracker.csv` |
| Closed Won - Pilot | Floor-priced order form signed + onboarding fee paid | `docs/sales/cycle-003-pilot-001-order-form.md` |
| Active Pilot | Hosted API workflow completed: ingest -> draft -> approve -> export | `projects/security-questionnaire-autopilot/runs/pilot-hosted-smoke-20260213-120836/export_package/manifest.json` |

## Hosted Workflow Gate Execution (Pilot #1)
| Workflow Step | Timestamp (PT) | Gate Result | Artifact |
|---|---|---|---|
| Ingest | 2026-02-13 12:00:39 | Pass | `projects/security-questionnaire-autopilot/runs/pilot-001-live-2026-02-13/questionnaire.csv` |
| Draft | 2026-02-13 12:00:39 | Pass (`all_answers_have_citations=true`) | `projects/security-questionnaire-autopilot/runs/pilot-001-live-2026-02-13/draft_answers.json` |
| Human Approval | 2026-02-13 12:00:39 | Pass (`all_approved=true`) | `projects/security-questionnaire-autopilot/runs/pilot-001-live-2026-02-13/approval.json` |
| Export | 2026-02-13 12:00:39 | Pass (`all_cited=true`, `human_approved=true`) | `projects/security-questionnaire-autopilot/runs/pilot-001-live-2026-02-13/export_package/manifest.json` |

## Hosted API Proof Run (Pilot #1)
| Workflow Step | Timestamp (PT) | Gate Result | Artifact |
|---|---|---|---|
| Ingest | 2026-02-13 12:08:37 | Pass | `projects/security-questionnaire-autopilot/runs/pilot-hosted-smoke-20260213-120836/questionnaire.csv` |
| Draft | 2026-02-13 12:08:38 | Pass (`all_answers_have_citations=true`) | `projects/security-questionnaire-autopilot/runs/pilot-hosted-smoke-20260213-120836/draft_answers.json` |
| Human Approval | 2026-02-13 12:08:38 | Pass (`all_approved=true`) | `projects/security-questionnaire-autopilot/runs/pilot-hosted-smoke-20260213-120836/approval.json` |
| Export | 2026-02-13 12:08:38 | Pass (`all_cited=true`, `human_approved=true`) | `projects/security-questionnaire-autopilot/runs/pilot-hosted-smoke-20260213-120836/export_package/manifest.json` |

## 3) Concrete Acquisition Channels
- `founder_intro`:
  - Used for pilot #1 close.
  - Channel priority for pilot #2/#3 because lower CAC and faster procurement.
- `targeted outbound` (Head of Security / VP Engineering):
  - Used to build next 2 pilot opportunities while pilot #1 activates.
- `compliance partner referrals`:
  - Backup channel for deal quality and faster trust transfer.

## 4) Trackable KPIs (Pilot #1 Snapshot)
- Commercial:
  - Onboarding revenue booked: `$2,000`
  - New MRR booked: `$1,800`
  - Expected monthly revenue at 14 questionnaires: `$2,100`
- Gate compliance:
  - Citation coverage on export: `100%`
  - Human approval coverage on export: `100%`
- Economics:
  - Projected monthly COGS (`14 * $35`): `$490`
  - Projected gross margin: `76.67%` (passes 70% floor)
  - Margin gate file: `docs/sales/cycle-003-pilot-001-margin-validation-pass.json`

## 5) Pricing/Package Adjustments
- No price changes approved for Cycle 003.
- Enforced package:
  - `$2,000` onboarding
  - `$1,800/mo` includes 12 questionnaires
  - `$150` overage above 12
- Discount-block proof artifact:
  - `docs/sales/cycle-003-pilot-001-margin-validation-floor-fail.json` (monthly fee below `$1,800` is rejected).

## Hosted Rollout Sales Acceptance Criteria
- Next.js + Supabase hosted workflow remains blocked from customer delivery unless:
  1. Citation gate passes (`no uncited answers`).
  2. Human approval gate passes (`all questions approved`).
  3. Pricing floor + margin gate passes before onboarding and expansion quotes.

## Cycle 003 Next Action (Completed)
Run the first customer-originated hosted intake (non-template questionnaire) on `2026-02-13` and attach the new run ID + export manifest in this file.

## Cycle 004 Customer-Originated Hosted Intake (Pilot #1)
Run executed on `2026-02-13` using non-template intake docs over hosted Next.js API.

| Workflow Step | Timestamp (PT) | Gate Result | Artifact |
|---|---|---|---|
| Validate Pilot Deal | 2026-02-13 12:16:25 | Pass (`approved=true`, `grossMargin=0.7667`) | `docs/qa/cycle-004-hosted-validate-pass.json` |
| Ingest (custom questionnaire + sources) | 2026-02-13 12:16:26 | Pass (`chunkCount=15`) | `docs/qa/cycle-004-hosted-customer-ingest.json` |
| Draft | 2026-02-13 12:16:26 | Pass (`all_answers_have_citations=true`) | `docs/qa/cycle-004-hosted-customer-draft.json` |
| Human Approval | 2026-02-13 12:16:26 | Pass (`unresolvedQuestionIds=[]`) | `docs/qa/cycle-004-hosted-customer-approve.json` |
| Export | 2026-02-13 12:16:26 | Pass (`all_cited=true`, `human_approved=true`) | `docs/qa/cycle-004-hosted-customer-export.json` |

- Run ID: `pilot-001-customer-originated-20260213-121619`
- Export manifest (source): `projects/security-questionnaire-autopilot/runs/pilot-001-customer-originated-20260213-121619/export_package/manifest.json`
- Export manifest (copied evidence): `docs/qa/cycle-004-hosted-customer-export-manifest.json`

## Supabase Migration/Seed Status (Cycle 004)
- Status: `blocked in current environment`.
- Reason: `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are not set; `supabase` and `psql` CLIs are unavailable.
- Blocker artifact: `docs/devops/cycle-004-supabase-migration-attempt.txt`

## Updated Next Action
Apply Supabase migration + seed in the credentialed hosted environment, then rerun one customer-originated hosted intake and attach DB evidence (`workflow_runs` + `workflow_events`) in this file.

## Supabase Persistence Evidence (To Attach After Credentialed Run)
After running the hosted intake against the deployed base URL with Supabase env vars set on the server:
- Attach `POST /api/workflow/db-evidence` response JSON for the new run ID.
  - Produced by: `projects/security-questionnaire-autopilot/scripts/hosted-workflow-customer-intake.sh`
  - Evidence file: `/tmp/hosted-intake-<run_id>/responses/06-db-evidence.json.pretty`
- Optionally also attach the direct PostgREST evidence artifact:
  - `docs/devops/cycle-005-supabase-persistence-<run_id>.json`

## Cycle 005 Supabase Persistence Unblock Artifacts
- Runbook (exact apply + verify steps): `docs/devops/cycle-005-credentialed-supabase-apply-runbook.md`
- QA acceptance for DB persistence proof: `docs/qa/cycle-005-db-persistence-acceptance.md`
- Ops unblock plan + owner/sequence: `docs/operations/cycle-005-unblock-plan.md`

### Shipped DB Evidence Collectors (Require Supabase Env Vars)
- Hosted evidence endpoint:
  - `POST /api/workflow/db-evidence` (implemented in `projects/security-questionnaire-autopilot/app/api/workflow/db-evidence/route.ts`)
- Hosted env preflight (no secrets returned):
  - `GET /api/workflow/env-health` (implemented in `projects/security-questionnaire-autopilot/app/api/workflow/env-health/route.ts`)
- Direct DB evidence script (no Next.js required):
  - `node projects/security-questionnaire-autopilot/scripts/fetch-db-evidence.mjs <runId> <outFile>`
- Customer-intake capture helper:
  - `projects/security-questionnaire-autopilot/scripts/hosted-workflow-customer-intake.sh`

## Cycle 005 Supabase Persistence (DevOps Handoff)
Status as of `2026-02-13`: blocked in this runtime due to missing real Supabase credentials.

Artifacts shipped to make the credentialed apply + evidence capture a single command:
- Dashboard SQL Editor runbook (no DB URL required): `docs/devops/cycle-005-credentialed-supabase-apply-runbook.md`
- One-command runbook (requires `SUPABASE_DB_URL`): `docs/devops/cycle-005-supabase-migration-and-persistence-runbook.md`
- No-creds attempt log: `docs/devops/cycle-005-supabase-migration-attempt.txt`
- Wrapper (applies migration+seed, runs intake, fetches DB evidence): `projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh`
- Paste-ready SQL bundle (migration + seed): `projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`

Credentialed execution (fastest path when you only have Dashboard SQL Editor access):

```bash
# 1) Apply SQL bundle via Supabase Dashboard SQL Editor:
#    projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql
#
# 2) Ensure the hosted runtime has:
#    NEXT_PUBLIC_SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
#
# 3) Run one customer-originated hosted intake + fetch DB evidence:
export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."
export SKIP_SUPABASE_SQL_APPLY=1

BASE_URL="https://<your-hosted-app-domain>"
RUN_ID="pilot-001-customer-originated-db-$(date +%Y%m%d-%H%M%S)"
./projects/security-questionnaire-autopilot/scripts/cycle-005-hosted-supabase-apply-and-run.sh "$BASE_URL" "$RUN_ID"
```

When executed with real creds, attach the generated persistence evidence JSON here:
- `docs/devops/cycle-005-supabase-persistence-<run_id>.json` (contains `workflow_runs` + `workflow_events` rows)

The wrapper now also captures a hosted Supabase reachability check:
- `docs/qa/cycle-005-supabase-health-<run_id>.json` (calls `GET /api/workflow/supabase-health`)

## Cycle 005 DB Persistence Evidence Log
Append-only log. Each entry links a hosted run ID to a concrete `workflow_runs` + `workflow_events` evidence artifact.

Operator runbook (GitHub Actions workflow_dispatch): `docs/sales/cycle-005-hosted-persistence-evidence-operator-runbook.md`
