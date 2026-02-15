#!/usr/bin/env node
/**
 * Fetch persistence evidence for a given RUN_ID from Supabase PostgREST.
 *
 * This intentionally avoids importing `@supabase/supabase-js` so the script can
 * run in environments that haven't pinned Node to >=20 yet.
 *
 * Requires service role credentials in env.
 */

import fs from "node:fs";
import process from "node:process";

function usage() {
  console.error(
    [
      "Usage:",
      "  fetch-supabase-workflow-evidence.mjs --run-id <id> [--out <path>]",
      "",
      "Env:",
      "  NEXT_PUBLIC_SUPABASE_URL",
      "  SUPABASE_SERVICE_ROLE_KEY",
      ""
    ].join("\n")
  );
}

function getArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return null;
  return process.argv[idx + 1] ?? null;
}

async function main() {
  const runId = getArg("--run-id");
  const outPath = getArg("--out");
  if (!runId) {
    usage();
    process.exit(2);
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    console.error("Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    usage();
    process.exit(2);
  }

  const restBase = url.replace(/\/+$/, "") + "/rest/v1";
  const headers = {
    apikey: key,
    Authorization: `Bearer ${key}`,
    Accept: "application/json"
  };

  const runUrl =
    restBase +
    "/workflow_runs?select=*&run_id=eq." +
    encodeURIComponent(runId);
  const runResp = await fetch(runUrl, { headers });
  if (!runResp.ok) {
    throw new Error(`workflow_runs query failed: ${runResp.status} ${await runResp.text()}`);
  }
  const runRows = await runResp.json();
  const runRow = Array.isArray(runRows) && runRows.length > 0 ? runRows[0] : null;

  const eventsUrl =
    restBase +
    "/workflow_events?select=*&run_id=eq." +
    encodeURIComponent(runId) +
    "&order=" +
    encodeURIComponent("created_at.asc");
  const eventsResp = await fetch(eventsUrl, { headers });
  if (!eventsResp.ok) {
    throw new Error(`workflow_events query failed: ${eventsResp.status} ${await eventsResp.text()}`);
  }
  const eventRows = await eventsResp.json();

  const payload = {
    runId,
    fetchedAt: new Date().toISOString(),
    workflow_runs: runRow,
    workflow_events: Array.isArray(eventRows) ? eventRows : []
  };

  const json = JSON.stringify(payload, null, 2) + "\n";
  if (outPath) {
    fs.writeFileSync(outPath, json, "utf8");
    process.stdout.write(`Wrote ${outPath}\n`);
  } else {
    process.stdout.write(json);
  }
}

main().catch((err) => {
  console.error(err?.stack || String(err));
  process.exit(1);
});
