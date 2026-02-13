import { NextResponse } from "next/server";

// Safe env diagnostics for hosted runtime. Never returns secret values.
export async function GET() {
  return NextResponse.json(
    {
      ok: true,
      runtime: {
        node: process.version
      },
      env: {
        NEXT_PUBLIC_SUPABASE_URL: Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL),
        SUPABASE_SERVICE_ROLE_KEY: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY)
      }
    },
    { status: 200 }
  );
}

