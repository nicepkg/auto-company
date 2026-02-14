#!/usr/bin/env bash
set -euo pipefail

# Print operator guidance for configuring required Supabase env vars on the hosted runtime.
# Intentionally does not attempt to mutate provider settings; it only prints actionable steps.

BASE_URL="${1:-}"

infer_provider() {
  local s="${1:-}"
  if printf '%s' "$s" | grep -qiE 'vercel\\.app'; then
    printf '%s' "vercel"
    return 0
  fi
  if printf '%s' "$s" | grep -qiE 'pages\\.dev'; then
    printf '%s' "cloudflare_pages"
    return 0
  fi
  printf '%s' "unknown"
}

provider="$(infer_provider "$BASE_URL")"

cat >&2 <<EOF

Hosted runtime is missing required Supabase env vars:
  - NEXT_PUBLIC_SUPABASE_URL
  - SUPABASE_SERVICE_ROLE_KEY

These must be configured on the hosting provider for the deployed Next.js app (the one serving /api/workflow/*),
then you must redeploy for the new env to take effect.

Verify after redeploy:
  curl -sS "${BASE_URL:-<BASE_URL>}/api/workflow/env-health" | jq .

See: docs/qa/cycle-005-hosted-persistence-evidence-preflight.md
See: docs/devops/cycle-005-hosted-runtime-env-vars.md
See: docs/devops/cycle-005-vercel-env-sync-and-redeploy.md
EOF

case "$provider" in
  vercel)
    cat >&2 <<'EOF'

Vercel:
  1) Vercel Dashboard -> Project -> Settings -> Environment Variables
  2) Add NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (Production/Preview as needed)
  3) Trigger a new deployment

Optional (automation):
  - Configure repo secrets/vars per: docs/devops/cycle-005-vercel-env-sync-and-redeploy.md
  - Then re-run the Cycle 005 evidence workflow with attempt_vercel_env_sync=true
  - Or dispatch: .github/workflows/cycle-005-hosted-runtime-env-sync.yml
EOF
    ;;
  cloudflare_pages)
    cat >&2 <<'EOF'

Cloudflare Pages:
  1) Cloudflare Dashboard -> Workers & Pages -> Pages -> Project -> Settings
  2) Add NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (Production/Preview as needed)
  3) Trigger a new deployment
EOF
    ;;
  *)
    cat >&2 <<'EOF'

If you are unsure which host is serving the app:
  - Your correct BASE_URL must return 200 JSON from: GET <BASE_URL>/api/workflow/env-health
  - Marketing/static sites typically return HTML (not JSON) or 404 for /api/workflow/*
EOF
    ;;
esac

cat >&2 <<'EOF'

Note:
  - GitHub Actions secrets do not configure the hosted runtime; they are fallback-only.
EOF
