# Cycle 008 (CTO-Vogels): Make Cycle 005 BASE_URL + Evidence Runs Self-Healing / Self-Diagnosing

Date: 2026-02-14
Scope: `.github/workflows/cycle-005-hosted-persistence-evidence.yml` and hosted runtime discovery for `projects/security-questionnaire-autopilot`.

## 1) Constraints And Business Requirements

- **Primary objective:** Cycle 005 hosted persistence evidence should run end-to-end without maintainer guesswork.
- **Runtime providers:** Vercel or Cloudflare Pages (either may be the active production host).
- **Allowed dependencies:** whatever exists in GitHub Actions runners (bash/curl/jq/node) plus optional provider tokens.
- **Safety:** preflight must be read-only by default; any mutations (provider env upsert, repo variable updates, PR writes) must be explicitly gated.
- **Noise control:** no PR spam; scheduled refresh should be opt-in and should not create new PRs on every cron tick.

## 2) Current State (What Already Works)

The current workflow already implements the right reliability shape:

- Candidate sources (in precedence order): workflow input, repo variable `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, legacy vars, then best-effort discovery via:
  - GitHub Deployments (`projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-github-deployments.sh`)
  - Hosting APIs (`projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh`)
- Deterministic selection via runtime-owned contract:
  - `GET <BASE_URL>/api/workflow/env-health` must be `200` JSON with `ok=true` and env booleans.
- Self-heal attempt when env is missing:
  - Vercel: upsert env vars + redeploy + poll (`projects/security-questionnaire-autopilot/scripts/vercel-sync-supabase-env.sh`)
  - Cloudflare Pages: upsert env vars + optional deploy hook + poll (`projects/security-questionnaire-autopilot/scripts/cloudflare-pages-sync-supabase-env.sh`)
- Noise gating:
  - Scheduled runs are blocked unless `CYCLE_005_AUTORUN_ENABLED=true`.
  - Evidence PR uses a single branch (`cycle-005-hosted-persistence-evidence`) to avoid creating N PRs.

What’s still missing is: (1) more authoritative candidate collection (esp. Pages deployments/aliases and Vercel previews), (2) provider-safe heuristics (custom domains), and (3) failure bundles that make “what to do next” obvious from artifacts alone.

## 3) Failure Modes To Eliminate (Everything Fails, All The Time)

These are the recurring “human-time expensive” failures:

- **FM1: Stale or wrong candidate origins**
  - Vercel preview domains expire or become `DEPLOYMENT_NOT_FOUND`.
  - Cloudflare Pages preview deployments have distinct `*.pages.dev` URLs not captured by project/domains alone.
  - Custom domains may front the wrong app (marketing vs workflow runtime).

- **FM2: Provider misclassification**
  - Current Cloudflare auto-fix gate keys on `pages.dev` substring. This fails when Pages is behind a custom domain.

- **FM3: Discovery fails silently**
  - Hosting collectors are best-effort and currently suppress provider errors; when they return empty, the operator can’t tell if this is “no token”, “wrong project id”, “API changed”, or “permissions”.

- **FM4: PR noise and alert fatigue**
  - Cron every 6 hours can keep a PR “churning” even when evidence is stable and no action is needed.

## 4) Concrete Deliverables (Highest Leverage Changes)

### Deliverable A: Cloudflare Pages Candidate Collection v2 (Deployments + Aliases)

**Goal:** reliably produce fresh candidates even when production is a custom domain or when only preview URLs are available.

Implement/extend `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh` to include:

- `GET /accounts/{account_id}/pages/projects/{project_name}` (already used)
  - Keep `result.subdomain` and `result.domains`.
- `GET /accounts/{account_id}/pages/projects/{project_name}/domains` (already used)
  - Keep `.result[].name/domain/hostname` fallbacks.
- **NEW:** `GET /accounts/{account_id}/pages/projects/{project_name}/deployments?per_page=N`
  - Extract and output (normalized origins only):
    - the latest **production** deployment URL
    - 1-3 latest **preview** deployment URLs
    - any `aliases`/`deployment_aliases` fields Cloudflare returns (capture both names because APIs drift)

Safe heuristics:

- Prefer production deployment URL(s) first.
- Keep preview URLs as fallbacks (they are often the only fresh ones when production wasn’t promoted).
- Emit at most 6 candidates total (avoid probe storms).

Self-diagnosis additions:

- In non-STRICT mode, continue best-effort behavior.
- In STRICT mode (recommended for scheduled runs), if the Cloudflare API returns non-success, write a small “reason blob” artifact (HTTP code + response JSON) so the failure isn’t a black box.

### Deliverable B: Vercel Candidate Collection v2 (Preview Domains + Aliases)

**Goal:** stop relying on stale preview URLs and ensure we consider both production and preview deployment URLs.

Extend `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh` to:

- Query both targets:
  - `GET /v6/deployments?projectId=<id>&target=production`
  - `GET /v6/deployments?projectId=<id>&target=preview`
- Filter deployments where possible:
  - `state == READY` / `readyState == READY` (support both keys)
  - Prefer deployments for default branch (often `gitBranch` or similar metadata)
- Extract candidate origins from:
  - Project domains (`/v9/projects/{idOrName}/domains`) (keep)
  - Deployment URLs (`deployments[].url`) (keep)
  - **NEW:** deployment aliases, if present (commonly `aliases[]`), because the “real” URL may be a custom domain alias

Safe heuristics:

- Prefer (1) custom domains, then (2) stable `*.vercel.app` production, then (3) preview.
- Cap to 10 raw candidates before de-dupe; output max 6.

Self-diagnosis additions:

- In STRICT mode, write artifacts with:
  - the exact request URLs (minus token)
  - HTTP codes
  - response bodies (JSON)

### Deliverable C: Provider Detection That Works For Custom Domains

**Goal:** choose the correct auto-fix path (Vercel vs Pages) even when `BASE_URL` is a custom domain.

Add a small provider-detection probe used by the workflow right after BASE_URL selection:

- Request: `GET <BASE_URL>/api/workflow/env-health` and capture response headers.
- Heuristics (safe, header-only):
  - Vercel likely if headers include `x-vercel-id`, `x-vercel-cache`, or similar.
  - Cloudflare likely if headers include `cf-ray`, `server: cloudflare`, or `cf-cache-status`.

Use detection to:

- Replace `contains(base_url, 'pages.dev')` gating for Cloudflare env sync.
- Prefer querying the corresponding hosting API first when doing discovery.

### Deliverable D: “Failure Bundle” Artifacts (Make Runs Self-Diagnosing)

**Goal:** if a run is red, the artifact zip should contain everything needed to fix it without tribal knowledge.

Add/standardize artifacts (preflight) in the workflow:

- `preflight/selected-base-url.txt` (already in summary, but persist it)
- `preflight/provider-detected.txt` (e.g., `vercel|cloudflare|unknown`)
- `preflight/env-health.headers.txt` (redacted, no secrets)
- `preflight/hosting-discovery.*.json` (raw provider API outputs; only when tokens configured)
- `preflight/dns.txt` (optional: `dig +short <host>`; helps distinguish DNS vs app issues)

And, critically, emit **stable reason codes** into:

- `preflight/failure-reason.txt` (single line):
  - `ERR_NO_CANDIDATES`
  - `ERR_ENV_HEALTH_HTTP_<code>`
  - `ERR_ENV_HEALTH_NOT_JSON`
  - `ERR_MISSING_HOSTED_SUPABASE_ENV`
  - `ERR_SUPABASE_HEALTH_FAILED`
  - `ERR_HOSTING_API_AUTH`

This enables maintainers to triage by grepping artifacts, and later enables automated “action_required” messaging without guessing.

### Deliverable E: Candidate Auto-Persistence (Stop Re-Breaking BASE_URL)

**Goal:** once the workflow finds a working runtime, keep the system converged.

Add an opt-in step:

- After successful BASE_URL selection, persist a formatted candidate list back into `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`.

Rules to keep this safe:

- Default: OFF. Require explicit signal, e.g.:
  - workflow_dispatch input `persist_discovered_candidates=true`, or
  - repo variable `CYCLE_005_AUTOPERSIST_CANDIDATES=true`
- Only persist if:
  - at least one candidate passes `env-health ok=true`, and
  - the selected BASE_URL is included, and
  - the final list is de-duped and capped (2-6 origins).

This turns BASE_URL discovery into a self-healing loop: API discovery finds “fresh”, env-health validates “correct”, and persistence prevents regression.

### Deliverable F: Gating Changes To Avoid Noise / PR Spam

**Goal:** scheduled runs should not churn a PR unless there is a reason.

Current guard (`CYCLE_005_AUTORUN_ENABLED=true`) is good but not sufficient to prevent churn. Add one additional gate: **write-on-staleness**.

Proposal:

- Split schedule behavior into:
  - scheduled **preflight** always (cheap, read-only) OR every 6h
  - scheduled **evidence write** only if stale OR explicitly enabled

Two safe ways to implement staleness without external state:

1. Repo-variable staleness (preferred)
- Maintain a repo variable like `CYCLE_005_LAST_EVIDENCE_AT=YYYY-MM-DD`.
- Only allow evidence write if `today - last_evidence_at >= 1 day` (or 7 days).
- Update the variable only after a successful evidence run.

2. Repo-file staleness (no extra API writes)
- Parse `docs/sales/cycle-003-hosted-workflow-pilot-001-execution.md` for the latest `run_id=...` entry and derive its date.
- Skip evidence write if the latest entry is within threshold.

Additional anti-noise measures:

- If the PR for branch `cycle-005-hosted-persistence-evidence` is already open, do not force new commits more frequently than the staleness threshold.
- Keep `preflight_only=true` as the default for `workflow_dispatch` (already done).

## 5) Architecture Options (Tradeoffs)

### Option 1: Manual Candidates Only (Status Quo “Happy Path”)
- Mechanism: maintainer sets `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` once.
- Pros: simplest, least tokens.
- Cons: does not self-heal when providers rotate preview URLs or when the maintainer picked the wrong domain.

### Option 2: Provider-API Discovery + Runtime Probe (Recommended)
- Mechanism: use Vercel/Cloudflare APIs to collect fresh URLs, then select using env-health probe.
- Pros: self-healing against stale URLs; deterministic correctness check.
- Cons: requires tokens + minimal “API drift” maintenance; must capture diagnostics to keep it operable.

### Option 3: Full Auto-Discovery (Scan All Projects)
- Mechanism: list all provider projects in an account/team and probe each for env-health.
- Pros: minimal configuration.
- Cons: larger blast radius and risk (probing unrelated apps), higher API costs, easier to pick the wrong environment if multiple apps implement similar endpoints.

Recommendation: Option 2 with strict diagnostics and opt-in persistence.

## 6) Key Risks And How We Contain Blast Radius

- **Token risk:** provider tokens are powerful.
  - Mitigation: least-privilege tokens; only enable env-upsert automation behind explicit inputs.
- **Wrong-environment writes (prod vs preview):**
  - Mitigation: provider detection; explicit env targets; only mutate when env-health proves we are hitting the workflow runtime.
- **API drift:** provider response shapes change.
  - Mitigation: store raw JSON artifacts (STRICT mode) so fixes can be made quickly without reproducing locally.

## 7) Complexity And Ops Overhead (Estimate)

- Cloudflare Pages deployments/aliases collection: low-medium (1 script + workflow artifact wiring).
- Vercel preview + aliases: low-medium (1 script + filtering).
- Provider detection + gating refactor: low (header probe + conditions).
- Staleness gating: low (repo variable or ledger parse).

Net: these are the highest-leverage changes because they reduce “human hunt time” more than they add runtime complexity.

## Next Action

Implement Deliverables A-D first (Pages deployments/aliases, Vercel preview/aliases, provider detection, and failure-bundle artifacts), then add Deliverables E-F (auto-persist and staleness gating) once diagnostics are proven in 2 green preflight runs.
