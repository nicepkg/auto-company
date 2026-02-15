# Cycle 004 Hosted Customer-Originated Validation

Date: 2026-02-13
Run ID: `pilot-001-customer-originated-20260213-121619`

## Scope
Executed end-to-end hosted API flow with non-template customer-originated intake payload:
- pricing validate
- ingest custom questionnaire + three custom source documents
- draft with citation gate
- human approval gate
- export

## Results
- Pricing gate: pass (`approved=true`, projected gross margin `0.7667`).
  - Evidence: `docs/qa/cycle-004-hosted-validate-pass.json`
- Ingest: pass (`chunkCount=15`, `Questions=6`).
  - Evidence: `docs/qa/cycle-004-hosted-customer-ingest.json`
- Draft citation gate: pass (`all_answers_have_citations=true`, `uncited_question_ids=[]`).
  - Evidence: `docs/qa/cycle-004-hosted-customer-draft.json`
- Approval gate: pass (`unresolvedQuestionIds=[]`).
  - Evidence: `docs/qa/cycle-004-hosted-customer-approve.json`
- Export gate: pass (`all_cited=true`, `human_approved=true`).
  - Evidence: `docs/qa/cycle-004-hosted-customer-export.json`
  - Manifest copy: `docs/qa/cycle-004-hosted-customer-export-manifest.json`

## Intake Payload Artifacts
- Questionnaire: `docs/sales/cycle-004-pilot-001-customer-questionnaire.csv`
- Source 1: `docs/sales/cycle-004-pilot-001-source-security-program.md`
- Source 2: `docs/sales/cycle-004-pilot-001-source-incident-response.md`
- Source 3: `docs/sales/cycle-004-pilot-001-source-infrastructure-controls.md`

## Supabase Migration Status
- DB migration/seed could not be applied in this environment (`SUPABASE_*` unset; no `supabase`/`psql` CLI).
- Blocker evidence: `docs/devops/cycle-004-supabase-migration-attempt.txt`

## QA Conclusion
Hosted API successfully executed a customer-originated intake with hard gate compliance. Remaining risk is environment-level DB wiring, not workflow gate correctness.
