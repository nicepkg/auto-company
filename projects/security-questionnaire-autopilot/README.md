# Security Questionnaire Autopilot (MVP)

Cycle-003 MVP artifacts for a source-grounded security questionnaire workflow.

## Scope

This MVP ships the required end-to-end path:

1. `ingest` questionnaire + source evidence documents
2. `draft` source-grounded answers with citations
3. `approve` mandatory human review gate
4. `export` final bundle only after all gates pass

Additional business gate:

- `validate-pilot-deal` enforces pricing floor and margin protection for design partner pilots.

## Hard Gates Enforced

- No uncited answers: `draft` fails if any question has no citation.
- Human approval required: `export` fails unless `approval.json` exists with all questions approved.
- Margin protection: `validate-pilot-deal` fails if pricing floor or gross-margin floor is violated.

## Runbook

```bash
cd projects/security-questionnaire-autopilot
python -m sq_autopilot.cli ingest \
  --run-id acme-2026-02 \
  --questionnaire templates/questionnaire.template.csv \
  --sources templates/source-security-policy.md templates/source-incident-response.md

python -m sq_autopilot.cli draft --run-id acme-2026-02

# human reviewer edits template then saves as local file, e.g. /tmp/acme-decisions.csv
python -m sq_autopilot.cli approve \
  --run-id acme-2026-02 \
  --reviewer "Jane Reviewer" \
  --decisions /tmp/acme-decisions.csv

python -m sq_autopilot.cli export \
  --run-id acme-2026-02 \
  --output /tmp/acme-2026-02-export.zip
```

Validate pilot deal against floor pricing and margin gate:

```bash
python -m sq_autopilot.cli validate-pilot-deal \
  --onboarding-fee 2000 \
  --monthly-fee 1800 \
  --included-questionnaires 12 \
  --overage-fee 150 \
  --expected-questionnaires 15 \
  --estimated-cogs-per-questionnaire 35
```

## Folder Layout

- `src/sq_autopilot/cli.py`: CLI + gate enforcement
- `runs/<run-id>/`: per-customer run state and artifacts
- `templates/`: questionnaire, decision, and source-document templates

## Notes

- Sources currently support `.md`, `.txt`, `.csv`.
- Draft answers are extractive snippets from cited evidence chunks (MVP behavior).

## Hosted Next.js + Supabase Surface (Cycle-003)

The project now includes a hosted wrapper around the same gate logic under
`app/api/workflow/*`.

### Hosted API Routes

- `POST /api/workflow/validate-pilot-deal`
- `POST /api/workflow/ingest`
- `POST /api/workflow/draft`
- `POST /api/workflow/approve`
- `POST /api/workflow/export`

All workflow routes execute the existing Python CLI pipeline to preserve gate
parity and optionally persist run/event state to Supabase when these env vars
are set:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

### Local Hosted Smoke Run

```bash
cd projects/security-questionnaire-autopilot
npm install
npm run dev

# in a second shell
./scripts/hosted-workflow-smoke.sh http://localhost:3000
```

### Supabase Schema Assets

- Migration:
  `supabase/migrations/20260213_cycle003_hosted_workflow.sql`
- Seed:
  `supabase/seed/pilot-001-floor-pricing.sql`
