# Cycle 005 Hosted Persistence Evidence Workflow: QA Notes (DevOps)

Workflow under test: `.github/workflows/cycle-005-hosted-persistence-evidence.yml`

## Test Charters

1. Variable persistence: `persist_base_url_candidates=true` writes `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`
- Manual dispatch with `base_url="https://c1 https://c2"` and `persist_base_url_candidates=true`
- Expect: preflight artifact contains `preflight/input-base-url-candidates.*` and GitHub API response artifacts
- Expect: job summary includes `persisted_repo_variable: HOSTED_WORKFLOW_BASE_URL_CANDIDATES`

2. Preflight-only behavior: `preflight_only=true` stops before evidence + PR
- Manual dispatch with `preflight_only=true`
- Expect: artifacts `cycle-005-hosted-base-url-probe` and `cycle-005-hosted-preflight` uploaded
- Expect: no `peter-evans/create-pull-request` step executes
- Expect: job summary includes `preflight_only: true`

3. Autorun gating: schedule does nothing until `CYCLE_005_AUTORUN_ENABLED=true`
- Scheduled trigger with repo variable unset or not `true`
- Expect: run exits early and summary says "skipped (schedule gated)"

4. Enable autorun after preflight: `enable_autorun_after_preflight=true`
- Manual dispatch with `preflight_only=true` and `enable_autorun_after_preflight=true`
- Expect: step "Enable scheduled autorun gate after green preflight" runs
- Expect: job summary includes `schedule_gate_enabled: CYCLE_005_AUTORUN_ENABLED=true`
- Expect: subsequent schedule run proceeds beyond the gate check

5. Misconfiguration signal: missing BASE_URL candidates fails when it should
- Manual dispatch with empty `base_url` and no repo variable candidates
- Expect: job fails with clear summary + preflight artifacts
- Scheduled run with `CYCLE_005_AUTORUN_ENABLED=true` and missing candidates
- Expect: job fails (red), not a silent green no-op

## Quick Manual Commands (CLI Wrapper)

Preflight-only (do not create PR):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --preflight-only \
  --skip-sql-apply true
```

Preflight-only + enable schedule gate (via workflow input):

```bash
./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh \
  --candidates-file docs/devops/base-url-candidates.template.txt \
  --enable-autorun-after-preflight \
  --skip-sql-apply true
```

