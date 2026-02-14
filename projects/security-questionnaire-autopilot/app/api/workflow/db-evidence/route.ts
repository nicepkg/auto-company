import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase/server";
import { sanitizeRunId } from "@/lib/workflow/runtime";
import { WORKFLOW_SCHEMA } from "@/lib/workflow/schema-version";

type EvidenceBody = {
  runId: string;
};

export async function POST(request: Request) {
  let body: EvidenceBody;
  try {
    body = (await request.json()) as EvidenceBody;
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON body" }, { status: 400 });
  }

  let runId: string;
  try {
    runId = sanitizeRunId(body.runId);
  } catch (error) {
    return NextResponse.json({ ok: false, error: (error as Error).message }, { status: 400 });
  }

  let supabase;
  try {
    supabase = getSupabaseAdmin();
  } catch (error) {
    return NextResponse.json(
      { ok: false, error: (error as Error).message },
      { status: 400 }
    );
  }

  const runRes = await supabase
    .from("workflow_runs")
    .select("*")
    .eq("run_id", runId)
    .maybeSingle();

  if (runRes.error) {
    return NextResponse.json(
      { ok: false, error: `Failed to fetch workflow_runs: ${runRes.error.message}` },
      { status: 500 }
    );
  }

  const eventsRes = await supabase
    .from("workflow_events")
    .select("*")
    .eq("run_id", runId)
    .order("created_at", { ascending: true });

  if (eventsRes.error) {
    return NextResponse.json(
      { ok: false, error: `Failed to fetch workflow_events: ${eventsRes.error.message}` },
      { status: 500 }
    );
  }

  return NextResponse.json(
    {
      ok: true,
      runId,
      expectedSchema: WORKFLOW_SCHEMA,
      // Prefer snake_case for compatibility with the CLI evidence/validation scripts.
      workflow_runs: runRes.data ?? null,
      workflow_events: eventsRes.data ?? [],
      // Back-compat aliases (legacy scripts/endpoints).
      workflowRun: runRes.data ?? null,
      workflowEvents: eventsRes.data ?? []
    },
    { status: 200 }
  );
}
