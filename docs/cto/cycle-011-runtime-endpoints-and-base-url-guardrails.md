# Cycle 011: Workflow Runtime Identification Endpoints (BASE_URL Guardrails)

## Problem
We need a **deterministic way to validate a candidate `BASE_URL`** points to the deployed **Next.js workflow runtime** (the app serving `app/api/workflow/*`), not a marketing/static site, and not the wrong environment.

This repo does **not** contain a canonical production `BASE_URL` (domain is deployment-specific). Therefore, `BASE_URL` selection must be done by probing runtime-owned API endpoints.

## Minimal Endpoint Contract (Uniquely Identifies Workflow Runtime)

### 1) `GET /api/workflow/env-health`

**Expected behavior (valid BASE_URL):**
- HTTP `200`
- JSON body includes:
  - `{ ok: true }`
  - `env.NEXT_PUBLIC_SUPABASE_URL` as a boolean
  - `env.SUPABASE_SERVICE_ROLE_KEY` as a boolean

**Why this uniquely identifies the runtime:**
- Marketing/static sites commonly return HTML (or non-JSON) and will fail JSON parsing.
- Non-workflow Next.js deployments typically do not implement this exact route and JSON shape.

**Why it is safe to expose:**
- It returns **only booleans** for env presence, not secret values.
- It returns `process.version` (Node version) for low-cost runtime fingerprinting/debug, but still no secrets.

Implementation: `projects/security-questionnaire-autopilot/app/api/workflow/env-health/route.ts`

### 2) (Evidence-grade) `GET /api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1`

Use this when the goal is **hosted persistence evidence** (not just “is this the right app?”).

**Expected behavior (correct runtime + correct Supabase project + correct schema/seed):**
- HTTP `200`
- JSON body includes `{ ok: true }`

**What it guards against:**
- Supabase env vars missing (fails with `400` and `ok:false`).
- “Wrong Supabase project” or “schema not applied” (fails via `workflow_app_meta.schema_bundle_id` mismatch).
- “Table exists but schema drifted” (queries representative columns from `workflow_runs`, `workflow_events`, and optionally `pilot_deals`).
- Missing seed run (`pilot-001-live-2026-02-13`) when `requireSeed=1`.

Implementation: `projects/security-questionnaire-autopilot/app/api/workflow/supabase-health/route.ts`

## Practical Guardrail Flow
1. Candidate selection: treat `BASE_URL` as an input (human-provided domain(s) from the hosting provider), not derivable from code.
2. Fail-fast probe: call `GET <BASE_URL>/api/workflow/env-health` and require `200` + JSON `{ ok:true }`.
3. Evidence gate (Cycle 005): additionally require `GET <BASE_URL>/api/workflow/supabase-health?requireSeed=1&requirePilotDeals=1` returns `200` + `{ ok:true }` before writing any evidence.

This yields a low-cost “are we pointed at the real workflow runtime?” check and a higher-assurance “are we pointed at the correct database with the expected schema/seed?” check.

