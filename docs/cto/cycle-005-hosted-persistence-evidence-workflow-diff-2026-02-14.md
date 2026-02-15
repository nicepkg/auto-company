# Cycle 005 Hosted Persistence Evidence: Workflow Diff Notes (2026-02-14)

File changed: `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

## Changes Made
- Added `workflow_dispatch` inputs:
  - `persist_base_url_candidates`:
    - When `true`, the workflow formats and persists the provided `base_url` into repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.
  - `enable_autorun_after_preflight`:
    - When `true` and `preflight_only=true`, the workflow sets `CYCLE_005_AUTORUN_ENABLED=true` only after preflight is green.
- Added a workflow step to persist `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` via GitHub REST API (upsert semantics: PATCH then POST fallback).
- Added a workflow step to enable `CYCLE_005_AUTORUN_ENABLED=true` after green preflight (same upsert behavior).
- Expanded job permissions with `actions: write` to allow repo variable upserts.
- Quoted step names containing `:` so the workflow YAML is standards-compliant and parseable by common YAML parsers (PyYAML rejects unquoted `:` in plain scalars).
- Uploaded additional preflight artifacts for traceability:
  - raw/formatted candidate input
  - GitHub API responses for variable upserts

## Operational Impact
- Maintainers can do the entire “set candidates -> preflight -> enable schedule gate” workflow from the GitHub Actions UI without requiring separate manual edits in repo settings.
- The schedule remains explicitly gated by `CYCLE_005_AUTORUN_ENABLED=true` to avoid PR spam.

## Risk Notes
- Granting `actions: write` increases token capability for this workflow. Mitigation:
  - All mutating steps are guarded to run only on `workflow_dispatch` and only when the relevant input flags are explicitly set.

