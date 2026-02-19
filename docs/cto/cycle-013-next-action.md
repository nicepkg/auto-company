# Cycle 013: Next Action

Date: 2026-02-14

1) Add the missing provider ID helper scripts + the Cycle 012 provider ID runbook to the PR (they are referenced by BASE_URL discovery docs and unblock maintainers from having to guess account/project IDs).
2) Ask a maintainer to run `workflow_dispatch` for `cycle-005-hosted-persistence-evidence.yml` with:
   - `preflight_only=true`
   - `persist_base_url_candidates=true`
   - `base_url=<2-4 candidate origins>`
   and attach the resulting `cycle-005-hosted-preflight` artifact in the PR discussion.

