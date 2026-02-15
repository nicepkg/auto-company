# Cycle 013: PR Merge Notes (Hosted BASE_URL Discovery + Evidence)

Date: 2026-02-14

## Recommended Merge Stance

This work introduces a deterministic, failure-focused operator loop:

- **Discovery contract**: `GET /api/workflow/env-health` is the single authoritative probe for “is this the correct hosted workflow runtime?”
- **Preflight-first**: evidence generation is gated behind a preflight that:
  - selects the real runtime origin, and
  - verifies hosted Supabase env vars are present, and
  - (optionally) verifies Supabase schema/seed when `skip_sql_apply=true`.

This reduces blast radius (wrong `BASE_URL` and missing hosted env are the dominant failure modes) and makes Actions runs unambiguous (green/red).

## Maintainer-Deterministic Operator Path

1) Set repo variable once (preferred):
   - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` = 2-4 candidate origins (space/comma/newline separated).

2) Run GHA `workflow_dispatch` with `preflight_only=true` until green.

3) Only then run `preflight_only=false` to generate evidence + PR.

If an operator cannot edit repo variables directly, the workflow supports:
- `persist_base_url_candidates=true` + input `base_url` to upsert `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` via the workflow itself.

## Reliability/Failure Notes (Vogels Lens)

- **Everything fails**:
  - Discovery uses short timeouts and requires JSON; HTML is treated as a hard signal of “wrong domain”.
  - Missing hosted env vars is treated as a hard stop for evidence runs (no partial evidence).

- **Blast radius control**:
  - Scheduled runs are gated behind `CYCLE_005_AUTORUN_ENABLED=true` to prevent PR spam.
  - Preflight-only is read-only and prevented from applying SQL.

- **API-first contract**:
  - `env-health` should remain stable; treat breaking changes as a production contract break.
  - Maintain backwards compatibility for candidate variable names (legacy vars are accepted).

## Minimal Must-Haves Before Enabling Schedule

- Hosted runtime env is correctly configured (verify via `env-health`):
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Repository variable set:
  - `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- Only after a green preflight:
  - set `CYCLE_005_AUTORUN_ENABLED=true` (or use `enable_autorun_after_preflight=true` in workflow_dispatch)

