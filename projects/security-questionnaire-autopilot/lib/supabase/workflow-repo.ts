import { getSupabaseAdminOrNull } from "@/lib/supabase/server";
import { WORKFLOW_SCHEMA } from "@/lib/workflow/schema-version";

export type WorkflowRunStatus = "ingested" | "drafted" | "approved" | "exported" | "failed";

type RunPatch = {
  runId: string;
  status: WorkflowRunStatus;
  citationGatePassed?: boolean;
  approvalGatePassed?: boolean;
  reviewer?: string;
  exportBundlePath?: string;
  metadata?: Record<string, unknown>;
};

type EventPatch = {
  runId: string;
  step: string;
  status: "success" | "failed";
  payload?: Record<string, unknown>;
};

function withSchemaMetadata(metadata?: Record<string, unknown>): Record<string, unknown> {
  // Always stamp schema identity into workflow_runs so evidence can be traced to a specific bundle.
  return {
    ...(metadata ?? {}),
    schema_bundle_id: WORKFLOW_SCHEMA.bundleId,
    schema_bundle_sha256: WORKFLOW_SCHEMA.bundleSha256,
    schema_migration_sha256: WORKFLOW_SCHEMA.migrationSha256,
    schema_seed_sha256: WORKFLOW_SCHEMA.seedSha256
  };
}

export async function upsertWorkflowRun(patch: RunPatch): Promise<void> {
  const supabase = getSupabaseAdminOrNull();
  if (!supabase) {
    return;
  }

  const { error } = await supabase.from("workflow_runs").upsert(
    {
      run_id: patch.runId,
      status: patch.status,
      citation_gate_passed: patch.citationGatePassed ?? null,
      approval_gate_passed: patch.approvalGatePassed ?? null,
      reviewer: patch.reviewer ?? null,
      export_bundle_path: patch.exportBundlePath ?? null,
      metadata: withSchemaMetadata(patch.metadata),
      updated_at: new Date().toISOString()
    },
    { onConflict: "run_id" }
  );

  if (error) {
    console.error("Failed to upsert workflow_runs", error.message);
  }
}

export async function recordWorkflowEvent(event: EventPatch): Promise<void> {
  const supabase = getSupabaseAdminOrNull();
  if (!supabase) {
    return;
  }

  const { error } = await supabase.from("workflow_events").insert({
    run_id: event.runId,
    step: event.step,
    status: event.status,
    payload: event.payload ?? {}
  });

  if (error) {
    console.error("Failed to insert workflow_events", error.message);
  }
}
