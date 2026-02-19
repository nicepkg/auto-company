# Cycle 005: Deterministic Fallback Path (No Supabase Provisioning Secrets)

## Situation

As of 2026-02-14, the Supabase provisioning path is blocked because these GitHub Actions secrets are missing:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_ORG_SLUG`
- `SUPABASE_DB_PASSWORD`

We still need machine-checkable evidence that the Cycle 005 SQL bundle applies cleanly and verifies against a Postgres database.

## Fallback Strategy

Use GitHub Actions with a vanilla `postgres:15` service container (no Supabase Management API, no Supabase secrets).

Workflow:

- `.github/workflows/cycle-005-postgres-service-apply-verify.yml`

This workflow:

1. Checks out the repo
2. Runs `npm ci` for `projects/security-questionnaire-autopilot`
3. Applies the SQL bundle to `postgresql://postgres:postgres@localhost:5432/postgres` with SSL disabled
4. Writes `projects/security-questionnaire-autopilot/runs/supabase-verify.json`
5. Uploads that JSON as an artifact (`cycle-005-postgres-service-apply-verify`)

## One-Command Evidence Capture (Role-Owned Output)

This wrapper dispatches the workflow, waits for completion, downloads artifacts, and writes a stable `latest/` pointer under `docs/devops-hightower/`:

```bash
scripts/devops/run-cycle-005-fallback-postgres-service-evidence.sh \
  --repo junhengz/auto-company
```

If you get an HTTP 404 for the workflow, it means the workflow file is not present on the repo's default branch yet. The wrapper will write a machine-checkable error file under:

- `docs/devops-hightower/cycle-005/postgres-service-apply-verify/workflow-missing-on-remote-*.json`

Optional flags:

- `--sql-bundle projects/security-questionnaire-autopilot/supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql`
- `--ref <branch-or-sha>`
- `--no-watch` (dispatch only; prints run id)
- `--run-id <id>` (download evidence only)
- `--out-dir docs/devops-hightower/cycle-005/postgres-service-apply-verify`

## What To Check

Primary machine-checkable artifact:

- `docs/devops-hightower/cycle-005/postgres-service-apply-verify/latest/supabase-verify.json`

“Green” means:

- `ok: true`
- All required tables exist
- `workflow_app_meta.schema_bundle_id` matches `supabase/bundles/workflow-schema-version.json`
- Seed row `pilot-001-live-2026-02-13` exists in `workflow_runs`

Pointer/metadata file:

- `docs/devops-hightower/cycle-005/postgres-service-apply-verify/latest/run.json`
