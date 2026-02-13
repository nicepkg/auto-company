import { NextResponse } from "next/server";
import { getSupabaseAdminOrNull } from "@/lib/supabase/server";
import { WORKFLOW_SCHEMA } from "@/lib/workflow/schema-version";

const EXPECTED_SCHEMA_BUNDLE_ID = WORKFLOW_SCHEMA.bundleId;

export async function GET(request: Request) {
  const url = new URL(request.url);
  const requireSeed = url.searchParams.get("requireSeed") === "1";
  const requirePilotDeals = url.searchParams.get("requirePilotDeals") === "1";
  const requireSchema = url.searchParams.get("requireSchema") !== "0";

  const hasUrl = Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL);
  const hasServiceRole = Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY);

  const supabase = getSupabaseAdminOrNull();
  if (!supabase) {
    return NextResponse.json(
      {
        ok: false,
        env: {
          NEXT_PUBLIC_SUPABASE_URL: hasUrl,
          SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
        },
        error: "Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY."
      },
      { status: 400 }
    );
  }

  let schemaBundleId: string | null = null;
  if (requireSchema) {
    const metaRes = await supabase
      .from("workflow_app_meta")
      .select("meta_key,meta_value")
      .eq("meta_key", "schema_bundle_id")
      .maybeSingle();
    if (metaRes.error) {
      return NextResponse.json(
        {
          ok: false,
          env: {
            NEXT_PUBLIC_SUPABASE_URL: hasUrl,
            SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
          },
          error: `workflow_app_meta not queryable: ${metaRes.error.message}`
        },
        { status: 500 }
      );
    }

    schemaBundleId = metaRes.data?.meta_value ?? null;
    if (!schemaBundleId) {
      return NextResponse.json(
        {
          ok: false,
          env: {
            NEXT_PUBLIC_SUPABASE_URL: hasUrl,
            SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
          },
          schema: {
            required: true,
            expected_schema_bundle_id: EXPECTED_SCHEMA_BUNDLE_ID,
            actual_schema_bundle_id: schemaBundleId
          },
          error:
            "Missing workflow_app_meta.schema_bundle_id; apply the SQL bundle before running hosted evidence."
        },
        { status: 500 }
      );
    }
    if (schemaBundleId !== EXPECTED_SCHEMA_BUNDLE_ID) {
      return NextResponse.json(
        {
          ok: false,
          env: {
            NEXT_PUBLIC_SUPABASE_URL: hasUrl,
            SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
          },
          schema: {
            required: true,
            expected_schema_bundle_id: EXPECTED_SCHEMA_BUNDLE_ID,
            actual_schema_bundle_id: schemaBundleId
          },
          error: "Schema bundle mismatch; evidence would be non-comparable. Apply the expected bundle."
        },
        { status: 500 }
      );
    }
  }

  // Query a representative set of columns so "table exists" doesn't mask schema drift.
  const runsRes = await supabase
    .from("workflow_runs")
    .select(
      "run_id,status,citation_gate_passed,approval_gate_passed,reviewer,export_bundle_path,metadata,created_at,updated_at"
    )
    .limit(1);
  if (runsRes.error) {
    return NextResponse.json(
      {
        ok: false,
        env: {
          NEXT_PUBLIC_SUPABASE_URL: hasUrl,
          SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
        },
        error: `workflow_runs not queryable: ${runsRes.error.message}`
      },
      { status: 500 }
    );
  }

  const eventsRes = await supabase
    .from("workflow_events")
    .select("id,run_id,step,status,payload,created_at")
    .limit(1);
  if (eventsRes.error) {
    return NextResponse.json(
      {
        ok: false,
        env: {
          NEXT_PUBLIC_SUPABASE_URL: hasUrl,
          SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
        },
        error: `workflow_events not queryable: ${eventsRes.error.message}`
      },
      { status: 500 }
    );
  }

  let pilotDealsQueryable = true;
  if (requirePilotDeals) {
    const pilotDealsRes = await supabase
      .from("pilot_deals")
      .select(
        "id,run_id,onboarding_fee,monthly_fee,included_questionnaires,overage_fee,expected_questionnaires,estimated_cogs_per_questionnaire,projected_gross_margin,approved,issues,created_at"
      )
      .limit(1);
    if (pilotDealsRes.error) {
      return NextResponse.json(
        {
          ok: false,
          env: {
            NEXT_PUBLIC_SUPABASE_URL: hasUrl,
            SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
          },
          error: `pilot_deals not queryable: ${pilotDealsRes.error.message}`
        },
        { status: 500 }
      );
    }
  }

  const seedRunId = "pilot-001-live-2026-02-13";
  const seedRes = await supabase
    .from("workflow_runs")
    .select("run_id,status,created_at,updated_at")
    .eq("run_id", seedRunId)
    .maybeSingle();
  if (seedRes.error) {
    return NextResponse.json(
      {
        ok: false,
        env: {
          NEXT_PUBLIC_SUPABASE_URL: hasUrl,
          SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
        },
        error: `Seed row check failed: ${seedRes.error.message}`
      },
      { status: 500 }
    );
  }
  const seedPresent = Boolean(seedRes.data);
  if (requireSeed && !seedPresent) {
    return NextResponse.json(
      {
        ok: false,
        env: {
          NEXT_PUBLIC_SUPABASE_URL: hasUrl,
          SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
        },
        error: `Required seed row missing from workflow_runs: run_id=${seedRunId}`,
        seed: {
          required: true,
          run_id: seedRunId,
          present: false
        }
      },
      { status: 500 }
    );
  }

  return NextResponse.json(
    {
      ok: true,
      env: {
        NEXT_PUBLIC_SUPABASE_URL: hasUrl,
        SUPABASE_SERVICE_ROLE_KEY: hasServiceRole
      },
      tables: {
        workflow_app_meta: requireSchema ? true : "not_checked",
        workflow_runs: true,
        workflow_events: true,
        pilot_deals: requirePilotDeals ? pilotDealsQueryable : "not_checked"
      },
      schema: {
        required: requireSchema,
        expected_schema_bundle_id: EXPECTED_SCHEMA_BUNDLE_ID,
        actual_schema_bundle_id: schemaBundleId
      },
      seed: {
        required: requireSeed,
        run_id: seedRunId,
        present: seedPresent
      }
    },
    { status: 200 }
  );
}
