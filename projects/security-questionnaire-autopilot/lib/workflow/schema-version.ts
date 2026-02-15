import schema from "@/supabase/bundles/workflow-schema-version.json";

export type WorkflowSchemaVersion = {
  bundleId: string;
  bundleSha256: string;
  migrationSha256: string;
  seedSha256: string;
};

// Single source of truth for "what schema did we intend to run with" so:
// - workflow_runs metadata can stamp it
// - db-evidence can report it
// - validation can detect schema/evidence drift
export const WORKFLOW_SCHEMA: WorkflowSchemaVersion = schema as WorkflowSchemaVersion;

