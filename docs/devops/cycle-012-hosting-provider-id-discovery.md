# Cycle 012: Hosting Provider ID Discovery (Vercel + Cloudflare Pages)

Goal: make it easy for a maintainer to supply the minimal provider inputs needed for hosted `BASE_URL` autodiscovery and Cycle 005.

This repo can discover candidate runtime origins from:

- Vercel API (needs project id or project name)
- Cloudflare Pages API (needs project name; account id is optional if the token only sees one account or `CLOUDFLARE_ACCOUNT_NAME` is set)

## Vercel: Find Project Name/ID

Required env:

- `VERCEL_TOKEN`
- Optional (team scope): `VERCEL_TEAM_ID` and/or `VERCEL_TEAM_SLUG`

Run:

```bash
export VERCEL_TOKEN="..."
# Optional:
# export VERCEL_TEAM_ID="..."
# export VERCEL_TEAM_SLUG="..."

./projects/security-questionnaire-autopilot/scripts/vercel-list-projects.sh
```

Pick either:

- `VERCEL_PROJECT=<project_name>` (recommended) or
- `VERCEL_PROJECT_ID=<project_id>`

Then hosting discovery can run:

```bash
export VERCEL_PROJECT="your-project-name"
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-vercel-api.sh
```

## Cloudflare: Find Account ID + Pages Project Name

Required env:

- `CLOUDFLARE_API_TOKEN`

Optional env:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ACCOUNT_NAME` (if the token can access multiple accounts)

List accounts:

```bash
export CLOUDFLARE_API_TOKEN="..."
./projects/security-questionnaire-autopilot/scripts/cloudflare-list-accounts.sh
```

List Pages projects (auto-resolves account id when possible):

```bash
export CLOUDFLARE_API_TOKEN="..."
# Optional if multiple accounts:
# export CLOUDFLARE_ACCOUNT_NAME="Your Account Name"

./projects/security-questionnaire-autopilot/scripts/cloudflare-pages-list-projects.sh
```

Set:

- `CF_PAGES_PROJECT=<project_name>`

Then hosting discovery can run:

```bash
export CF_PAGES_PROJECT="your-pages-project"
./projects/security-questionnaire-autopilot/scripts/collect-base-url-candidates-from-cloudflare-pages-api.sh
```

## End-To-End: Discover + Probe The Real Runtime

Once provider env vars are set, you can collect and probe candidates in one shot:

```bash
./projects/security-questionnaire-autopilot/scripts/select-hosted-base-url.sh
```

It will only accept a candidate that returns `200` JSON from `GET /api/workflow/env-health`.

