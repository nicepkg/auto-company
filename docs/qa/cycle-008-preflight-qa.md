# Cycle 008 Preflight QA (Cycle 005 Hosted Runtime Gate)

Date: 2026-02-14  
Role: qa-bach  
Scope: minimal validation path that (1) catches wrong `BASE_URL` (HTML/404/non-JSON) and (2) catches missing hosted env vars, plus (3) sanity-checks hosting candidate discovery scripts.

## Quality Risks This Gate Is Designed To Catch

- **Wrong `BASE_URL`** (points at marketing/static domain, dead preview URL, redirect target, or other service): `/api/workflow/env-health` returns `404`, `3xx`, `5xx`, or `200` with **HTML** (non-JSON).
- **Hosted runtime missing required Supabase env vars** (deployment is the right app, but not configured): `/api/workflow/env-health` returns `200` JSON with `ok=true` but booleans show missing env.
- **Discovery scripts returning junk candidates**: paths instead of origins, missing scheme handling, duplicates, non-URL garbage, or scripts failing hard when creds are absent (should be best-effort no-op).

## Minimal QA Validation Path (Operator-Executable)

### Step 0: Preconditions (Local Shell)

Required binaries for the preflight commands below:
- `curl`
- `jq`

### Step 1: Candidate Triage Table (Fast Signal For HTML/404)

Input: `2-6` candidate domains/origins (mix is OK: custom domain, `*.vercel.app`, `*.pages.dev`).

Command:

```bash
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh \
  "https://candidate1 https://candidate2"
```

Pass signal (at least one row):
- `http` is `200`
- `ok` is `true`
- `supabase_url` is `true`
- `service_role` is `true`

Fail signals that specifically catch the target risks:
- Wrong `BASE_URL` (HTML/404): `http` is `404` or `000`, or `note` contains `content-type: text/html` and a `body_head='<html...`.
- Missing hosted env vars: `http` is `200`, `ok=true`, but `supabase_url` or `service_role` is `false` (or `-`).

Evidence to keep (copy/paste into ticket/PR comment):
- the printed table (full output)

### Step 2: Deterministic Selection (Should Reject HTML/Non-JSON)

Command (same candidates; first valid wins):

```bash
BASE_URL="$(
  ./projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh \
    "https://candidate1 https://candidate2"
)"
echo "$BASE_URL"
```

Pass criteria:
- exits `0`
- prints a single origin like `https://app.example.com` (no path, no trailing slash)

Fail criteria (and what it means):
- exits non-zero with reasons including:
- `env-health HTTP <code>`: dead/wrong service (often `404`).
- `env-health not JSON (...) body_sniff=...`: **wrong `BASE_URL`** (marketing/static HTML).
- `missing Supabase env vars`: **right runtime**, wrong/missing hosting provider env config.

### Step 3: Env-Health Gate (Missing Hosted Env Vars Must Fail Fast)

Command:

```bash
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Pass criteria (minimum required for Cycle 005 evidence runs):
- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

Fail criteria:
- any boolean above is `false` (or missing): treat as a hard block for Cycle 005 evidence.

### Step 4: Runtime Smoke (Confirms Supabase Health Also Works)

Command:

```bash
./projects/security-questionnaire-autopilot/scripts/smoke-hosted-runtime.sh "$BASE_URL"
```

Pass criteria:
- exits `0`
- prints a path like `/tmp/hosted-runtime-smoke/smoke-summary.json`
- summary JSON has `.ok == true`, `.checks.env_health == true`, and `.checks.supabase_health == true`

Fail criteria:
- `supabase-health failed` or `.ok != true`: schema/seed/env mismatch; do not proceed to evidence run.

## Test Charters (Exploratory Sessions, 20-40 Minutes Each)

### Charter A: BASE_URL Selection Is Robust Against “Looks Right” Domains

Mission:
- prove the selection tools reject marketing/static domains and dead preview deployments quickly and with actionable diagnostics.

Coverage ideas:
- a candidate that returns `200 text/html` at `/` and `404` at `/api/workflow/env-health`
- a candidate that returns `200 text/html` at `/api/workflow/env-health` (e.g., CDN rewrite)
- a candidate with a path (e.g., `https://host/app`): ensure it is normalized to origin

Oracles:
- `discover-hosted-base-url.sh` should not accept non-JSON even when HTTP is `200`
- `probe-hosted-base-url-candidates.sh` should surface `content-type` and `body_head` for fast diagnosis

Artifacts:
- paste the `probe-hosted-base-url-candidates.sh` table into `docs/qa/` notes or the issue

### Charter B: Env-Health Truthfulness (Hosted Runtime Env Vars)

Mission:
- demonstrate that “hosted runtime is missing env vars” is caught *before* any destructive actions (SQL apply, evidence writes).

Coverage ideas:
- compare env-health output before and after hosting-provider env configuration + redeploy
- verify the endpoint never leaks secret values (should be booleans only)

Oracles:
- `smoke-hosted-runtime.sh` and `cycle-005-hosted-supabase-apply-and-run.sh` should fail with clear instructions when booleans are false

Artifacts:
- save `env-health.json` from the smoke summary directory

## Hosting Candidate Discovery Scripts (Plausibility Checks)

Scripts under test:
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh`
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh`
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh`
- `projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-github-deployments.sh`
- `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`

### Check 1: No-Creds Behavior Is Safe (Best-Effort No-Op)

Goal:
- without provider tokens, scripts should not crash or print garbage; they should print nothing and exit `0` where documented.

Commands (run in a shell with no related env vars exported):

```bash
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh | wc -l
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh | wc -l
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh | wc -l
```

Expected output shape:
- `0` lines (or at least “no output”), and exit code `0`.

### Check 2: With Creds, Output Looks Like Origins (Not Paths) And Is Deduped

Goal:
- when creds are present, output should be newline-separated origins, normalized.

Commands (credentialed environment):

```bash
STRICT=1 ./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh
```

Expected output shape (examples, not exact values):
- each line matches `^https?://[^/]+$`
- no duplicates
- no trailing slash
- plausible hostnames for your provider (examples): Vercel `*.vercel.app` and/or custom domains; Cloudflare Pages `*.pages.dev` and/or custom domains

Follow-up validation (connects discovery to the real gate):

```bash
BASE_URL_CANDIDATES="$(
  ./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh | tr '\n' ' '
)"
./projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh
./projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh
```

Pass criteria:
- probe table shows at least one valid candidate (200 + JSON + env booleans true)
- `select-hosted-base-url.sh` prints a single `BASE_URL` and exits `0`

### Check 3: GitHub Deployments Discovery Is Best-Effort (May Be Empty)

Goal:
- verify the script is usable when GitHub Deployments metadata exists, and harmless when it does not.

Commands (only if you have `GITHUB_REPOSITORY` + `GITHUB_TOKEN` available):

```bash
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-github-deployments.sh
```

Expected behavior:
- may print `0..N` lines; if metadata is absent, prints nothing and exits `0`
- if it prints candidates, they should be valid URLs with scheme and no trailing slash

## When To Stop (Hard Blocks)

Stop and fix before running Cycle 005 evidence if:
- no candidate returns `200` JSON from `/api/workflow/env-health`
- env-health returns `ok=true` but either required env boolean is `false`
- smoke fails `supabase-health`

## References

- `projects/security-questionnaire-autopilot/scripts/discover-hosted-base-url.sh`
- `projects/security-questionnaire-autopilot/scripts/probe-hosted-base-url-candidates.sh`
- `projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh`
- `projects/security-questionnaire-autopilot/scripts/smoke-hosted-runtime.sh`
- `docs/qa/cycle-005-hosted-persistence-evidence-preflight.md`
- `docs/devops/base-url-discovery.md`

## Next Action

Run Step 1 through Step 4 against your current candidate list; if any fail, capture the table + `env-health` JSON and route to the owner of hosting configuration (Vercel/Cloudflare) to correct `BASE_URL` and/or set hosted env vars then redeploy.
