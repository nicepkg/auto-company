import { NextResponse } from "next/server";

// This endpoint is used for operator checks + CI preflights. It must never be
// statically cached, otherwise env var updates (and "now") won't reflect reality.
export const dynamic = "force-dynamic";
export const revalidate = 0;

// Safe env diagnostics for hosted runtime. Never returns secret values.
export async function GET() {
  // Helpful for debugging "wrong BASE_URL" and "forgot to redeploy" issues.
  // These fields are safe to expose publicly (no secrets, only metadata).
  const vercel = {
    env: process.env.VERCEL_ENV ?? null,
    url: process.env.VERCEL_URL ?? null,
    region: process.env.VERCEL_REGION ?? null,
    git_commit_sha: process.env.VERCEL_GIT_COMMIT_SHA ?? null,
    git_commit_ref: process.env.VERCEL_GIT_COMMIT_REF ?? null
  };

  const cloudflarePages = {
    branch: process.env.CF_PAGES_BRANCH ?? null,
    commit_sha: process.env.CF_PAGES_COMMIT_SHA ?? null,
    url: process.env.CF_PAGES_URL ?? null,
    deployment_id: process.env.CF_PAGES_DEPLOYMENT_ID ?? null
  };

  const provider = process.env.VERCEL
    ? "vercel"
    : process.env.CF_PAGES
      ? "cloudflare_pages"
      : "unknown";

  return NextResponse.json(
    {
      ok: true,
      runtime: {
        node: process.version,
        now: new Date().toISOString()
      },
      deploy: {
        provider,
        vercel,
        cloudflare_pages: cloudflarePages
      },
      env: {
        NEXT_PUBLIC_SUPABASE_URL: Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL),
        SUPABASE_SERVICE_ROLE_KEY: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY)
      }
    },
    { status: 200 }
  );
}
