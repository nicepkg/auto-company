
---

# Next Action (SQ Autopilot Hosted Baseline)

1. Deploy the hosted runtime to Fly so `https://auto-company-sq-autopilot.fly.dev/api/workflow/env-health` returns `200` JSON.
2. Set `HOSTED_WORKFLOW_BASE_URL` on `junhengz/auto-company` (already set to the Fly origin in this cycle).
3. Run `sq-autopilot-hosted-integration` once on `main`.

Runbook: `docs/devops-hightower/cycle-003-sq-autopilot-hosted-baseline-2026-02-14.md`
