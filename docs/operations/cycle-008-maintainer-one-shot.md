# Cycle 008: Maintainer One-Shot (Cycle 005 BASE_URL + Hosted Env Blockers)

Audience: repo maintainer for `nicepkg/auto-company` with access to the hosting provider (Vercel and/or Cloudflare Pages).

Goal (under 15 min): produce an unambiguous green/red signal by (1) getting authoritative deployed app origins from the hosting provider, (2) setting `HOSTED_WORKFLOW_BASE_URL_CANDIDATES`, (3) running `preflight_only=true`, (4) if env is missing, setting hosting env vars + redeploying, then re-running preflight.

## What "Green" Looks Like

For at least one candidate origin:

```bash
BASE_URL="https://<candidate-origin>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq .
```

Green requirements:

- `.ok == true`
- `.env.NEXT_PUBLIC_SUPABASE_URL == true`
- `.env.SUPABASE_SERVICE_ROLE_KEY == true`

And the preflight workflow run succeeds and uploads artifact `cycle-005-hosted-preflight` that includes `preflight/env-health.json` and (when `skip_sql_apply=true`) `preflight/supabase-health.json` with `.ok == true`.

## 1) Get Authoritative BASE_URL Candidates (Hosting Provider)

You need 2-4 *origins* (scheme + host, no path), for the deployed Next.js runtime that serves `/api/workflow/*`.

### Option A (preferred): use the repo’s hosting discovery scripts (curl+jq inside)

From a checkout of this repo:

```bash
cd /path/to/auto-company

# Vercel discovery requires:
#   VERCEL_TOKEN
#   VERCEL_PROJECT_ID or VERCEL_PROJECT
# Optional: VERCEL_TEAM_ID and/or VERCEL_TEAM_SLUG
#
# Cloudflare Pages discovery requires:
#   CLOUDFLARE_API_TOKEN
#   CF_PAGES_PROJECT
# Optional:
#   CLOUDFLARE_ACCOUNT_ID
#   CLOUDFLARE_ACCOUNT_NAME   (if token can access multiple accounts)

./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-hosting.sh \
  | tee /tmp/hosted-base-url-candidates.txt
```

If that prints nothing, you’re missing provider env vars/tokens for API discovery. Use Option B or C.

If you need help finding provider account/project identifiers with this repo’s scripts, see:

- `docs/devops/cycle-012-hosting-provider-id-discovery.md`

### Option B: direct Vercel API (curl + jq)

```bash
export VERCEL_TOKEN="..."                    # required
export VERCEL_PROJECT_ID="..."               # OR: export VERCEL_PROJECT="..."
# Optional (team scope): export VERCEL_TEAM_ID="..." and/or export VERCEL_TEAM_SLUG="..."

ID_OR_NAME="${VERCEL_PROJECT_ID:-$VERCEL_PROJECT}"
QS=""
[ -n "${VERCEL_TEAM_ID:-}" ] && QS="${QS}${QS:+&}teamId=${VERCEL_TEAM_ID}"
[ -n "${VERCEL_TEAM_SLUG:-}" ] && QS="${QS}${QS:+&}slug=${VERCEL_TEAM_SLUG}"
[ -n "${QS:-}" ] && QS="?$QS"

# Project domains (custom domains and/or *.vercel.app):
curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v9/projects/${ID_OR_NAME}/domains${QS}" \
  | jq -r '.domains[]?.name? // empty' \
  | sed 's#^#https://#' \
  | tee /tmp/hosted-base-url-candidates.txt
```

### Option C: direct Cloudflare Pages API (curl + jq)

```bash
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
export CF_PAGES_PROJECT="..."

curl -sS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${CF_PAGES_PROJECT}" \
  | jq -r '.result.subdomain? // empty, (.result.domains[]? // empty)' \
  | sed 's#^#https://#' \
  | tee /tmp/hosted-base-url-candidates.txt
```

## 2) Validate Candidates Locally (Pick the Real Workflow Runtime)

Run this against each candidate you found; it should return JSON, not HTML:

```bash
while IFS= read -r u; do
  [ -n "$u" ] || continue
  u="${u%/}"
  echo ""
  echo "==> $u"
  curl -sS -m 12 "$u/api/workflow/env-health" | jq -r '{ok, env}'
done < /tmp/hosted-base-url-candidates.txt
```

Interpretation:

- If you get `jq: parse error` or HTML-ish output: wrong origin (marketing/static site).
- If `ok=true` but any `env.*` boolean is `false`: correct app, missing hosting env vars (fix in step 5).

## 3) Set `HOSTED_WORKFLOW_BASE_URL_CANDIDATES` (GitHub Repo Variable)

Set the variable once in the canonical repo; future runs can leave the workflow input `base_url` empty.

```bash
REPO="nicepkg/auto-company"

CANDIDATES="$(
  cat /tmp/hosted-base-url-candidates.txt \
    | sed 's/[[:space:]]*$//' \
    | sed '/^$/d' \
    | tr '\n' ' ' \
    | tr -s ' ' \
    | sed 's/^ *//; s/ *$//'
)"

gh auth status -h github.com
gh variable set HOSTED_WORKFLOW_BASE_URL_CANDIDATES -R "$REPO" --body "$CANDIDATES"
```

Optional sanity check (may 403 depending on org policy):

```bash
gh variable list -R "$REPO" | rg -n "HOSTED_WORKFLOW_BASE_URL_CANDIDATES|CYCLE_005_AUTORUN_ENABLED" || true
```

## 4) Run Preflight (preflight_only=true) and Interpret Results

Dispatch:

```bash
REPO="nicepkg/auto-company"
WF="cycle-005-hosted-persistence-evidence.yml"

gh workflow run "$WF" -R "$REPO" -f preflight_only=true -f skip_sql_apply=true
RUN_ID="$(gh run list -R "$REPO" --workflow "$WF" -L 1 --json databaseId -q '.[0].databaseId')"
gh run watch -R "$REPO" "$RUN_ID" --exit-status
```

Download and inspect the authoritative preflight artifacts:

```bash
OUT="/tmp/cycle-005-preflight-$RUN_ID"
rm -rf "$OUT"
gh run download -R "$REPO" "$RUN_ID" -n cycle-005-hosted-preflight -D "$OUT"

cat "$OUT/preflight/base-url-source.txt"
cat "$OUT/preflight/base-url-candidates.txt"
cat "$OUT/preflight/base-url-probe.txt"

cat "$OUT/preflight/env-health.json" | jq .
test -f "$OUT/preflight/supabase-health.json" && cat "$OUT/preflight/supabase-health.json" | jq . || true
```

Interpretation:

- Failure: “Missing BASE_URL candidates”
  - Fix: step 3 didn’t happen in the canonical repo, or you set the wrong repo.
- Failure: “env-health not JSON” / HTTP non-200
  - Fix: candidate origins are wrong (go back to step 1 and use the hosting provider’s domains for the deployed app).
- Failure: “Hosted runtime is missing required Supabase env vars”
  - Fix: step 5.
- Failure at `supabase-health` (`.ok != true` or HTTP non-200)
  - Fix is *not* BASE_URL: it means schema/seed isn’t present in Supabase yet; run the SQL apply path (not covered here), then re-run preflight.

## 5) If Hosted Env Is Missing: Set Env Vars on Hosting Provider + Redeploy

The deployed Next.js runtime must have these server-side env vars:

- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

After redeploy, this must be true:

```bash
BASE_URL="https://<the-real-origin>"
curl -sS "$BASE_URL/api/workflow/env-health" | jq -e '.ok==true and .env.NEXT_PUBLIC_SUPABASE_URL==true and .env.SUPABASE_SERVICE_ROLE_KEY==true'
```

### Option A: Vercel fast path (CLI via repo script)

```bash
export VERCEL_TOKEN="..."
export VERCEL_PROJECT_ID="..."       # or VERCEL_PROJECT="..."
export NEXT_PUBLIC_SUPABASE_URL="https://<your-project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

BASE_URL="https://<vercel-origin>"
./projects/security-questionnaire-autopilot/scripts/vercel-sync-supabase-env.sh "$BASE_URL"
```

### Option B: Cloudflare Pages fast path (CLI via repo script)

```bash
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
export CF_PAGES_PROJECT="..."
export NEXT_PUBLIC_SUPABASE_URL="https://<your-project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."

# Optional: set this if you want the script to trigger deploy automatically.
export CF_PAGES_DEPLOY_HOOK_URL="..."

BASE_URL="https://<pages-origin>"
./projects/security-questionnaire-autopilot/scripts/cloudflare-pages-sync-supabase-env.sh "$BASE_URL"
```

### Option C: provider UI (manual)

If you prefer clicking:

- Vercel: Project -> Settings -> Environment Variables
  - Add/update `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (Production at minimum), then redeploy.
- Cloudflare Pages: Project -> Settings -> Environment variables
  - Add/update the same two vars (Production), then trigger a new deployment.

Then re-run step 4.

## Next Action

Run step 4 (`gh workflow run ... -f preflight_only=true`) and fix any red state by looping step 5 once, until `env-health` is green.
