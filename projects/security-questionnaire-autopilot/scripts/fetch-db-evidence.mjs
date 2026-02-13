#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";

function usage(exitCode) {
  // Intentionally terse: this is invoked by ops during incident-like handoffs.
  console.error(
    "Usage: node scripts/fetch-db-evidence.mjs <runId> [outFile]\n" +
      "Env: NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY"
  );
  process.exit(exitCode);
}

const runId = process.argv[2];
if (!runId) usage(2);

const outFile = process.argv[3] || null;

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error("Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
  process.exit(2);
}

const supabase = createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false }
});

const workflowRunRes = await supabase
  .from("workflow_runs")
  .select("*")
  .eq("run_id", runId)
  .maybeSingle();

if (workflowRunRes.error) {
  console.error(`Failed to fetch workflow_runs: ${workflowRunRes.error.message}`);
  process.exit(1);
}

const workflowEventsRes = await supabase
  .from("workflow_events")
  .select("*")
  .eq("run_id", runId)
  .order("created_at", { ascending: true });

if (workflowEventsRes.error) {
  console.error(`Failed to fetch workflow_events: ${workflowEventsRes.error.message}`);
  process.exit(1);
}

const payload = {
  ok: true,
  runId,
  workflowRun: workflowRunRes.data ?? null,
  workflowEvents: workflowEventsRes.data ?? []
};

const json = JSON.stringify(payload, null, 2) + "\n";

if (!outFile) {
  process.stdout.write(json);
  process.exit(0);
}

const outPath = path.resolve(process.cwd(), outFile);
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, json, "utf8");
console.error(`Wrote DB evidence: ${outPath}`);

