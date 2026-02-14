#!/usr/bin/env node
/**
 * Verify that the expected migration + seed bundle has been applied to Supabase
 * by checking:
 * - required tables exist
 * - workflow_app_meta.schema_bundle_id matches the repo's expected bundleId
 * - required seed row exists in workflow_runs
 *
 * Output is non-secret JSON (no connection strings, no keys).
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { Client } from "pg";

function usage() {
  console.error(
    [
      "Usage:",
      "  verify-supabase-bundle-applied.mjs [--out <path>] [--require-schema 0|1] [--require-seed 0|1] [--expected-bundle-id <id>]",
      "",
      "Env:",
      "  SUPABASE_DB_URL (preferred) or DATABASE_URL",
      "  SUPABASE_DB_SSL: true|false (default: true)",
      "  SUPABASE_DB_SSL_REJECT_UNAUTHORIZED: true|false (default: true)"
    ].join("\n")
  );
}

function envBool(name, defaultValue) {
  const raw = process.env[name];
  if (raw == null || raw === "") return defaultValue;
  return raw.toLowerCase() === "true" || raw === "1" || raw.toLowerCase() === "yes";
}

function getArg(name) {
  const idx = process.argv.indexOf(name);
  if (idx === -1) return null;
  return process.argv[idx + 1] ?? null;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function readExpectedBundleId() {
  try {
    const p = path.resolve(process.cwd(), "supabase/bundles/workflow-schema-version.json");
    const raw = fs.readFileSync(p, "utf8");
    const json = JSON.parse(raw);
    if (typeof json?.bundleId === "string" && json.bundleId.length > 0) return json.bundleId;
    return null;
  } catch {
    return null;
  }
}

async function main() {
  if (hasFlag("-h") || hasFlag("--help")) {
    usage();
    process.exit(0);
  }

  const outPath = getArg("--out");
  const requireSchemaRaw = getArg("--require-schema");
  const requireSeedRaw = getArg("--require-seed");
  const expectedOverride = getArg("--expected-bundle-id");

  const requireSchema = requireSchemaRaw == null ? true : requireSchemaRaw !== "0";
  const requireSeed = requireSeedRaw == null ? true : requireSeedRaw !== "0";

  const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error("Missing SUPABASE_DB_URL (or DATABASE_URL).");
    usage();
    process.exit(2);
  }

  const expectedBundleId = expectedOverride || readExpectedBundleId();
  const seedRunId = "pilot-001-live-2026-02-13";

  const sslEnabled = envBool("SUPABASE_DB_SSL", true);
  const sslRejectUnauthorized = envBool("SUPABASE_DB_SSL_REJECT_UNAUTHORIZED", true);

  const client = new Client({
    connectionString,
    ssl: sslEnabled ? { rejectUnauthorized: sslRejectUnauthorized } : undefined
  });

  const result = {
    ok: false,
    checked_at_utc: new Date().toISOString(),
    expected: {
      schema_bundle_id: expectedBundleId,
      seed_run_id: seedRunId,
      require_schema: requireSchema,
      require_seed: requireSeed
    },
    actual: {
      schema_bundle_id: null,
      seed_present: null,
      tables: {
        workflow_app_meta: null,
        workflow_runs: null,
        workflow_events: null,
        pilot_deals: null
      }
    },
    error: null
  };

  const q1 = async (text, params = []) => {
    const res = await client.query(text, params);
    return res.rows;
  };

  try {
    await client.connect();

    const tables = [
      "public.workflow_app_meta",
      "public.workflow_runs",
      "public.workflow_events",
      "public.pilot_deals"
    ];
    for (const t of tables) {
      const rows = await q1("select to_regclass($1) as r", [t]);
      const exists = rows?.[0]?.r != null;
      const short = t.split(".")[1];
      result.actual.tables[short] = exists;
    }

    if (requireSchema) {
      const metaRows = await q1(
        "select meta_value from public.workflow_app_meta where meta_key = 'schema_bundle_id' limit 1"
      );
      result.actual.schema_bundle_id = metaRows?.[0]?.meta_value ?? null;
    }

    const seedRows = await q1(
      "select exists(select 1 from public.workflow_runs where run_id = $1) as present",
      [seedRunId]
    );
    result.actual.seed_present = Boolean(seedRows?.[0]?.present);

    const schemaOk =
      !requireSchema ||
      (expectedBundleId != null &&
        result.actual.schema_bundle_id != null &&
        result.actual.schema_bundle_id === expectedBundleId);

    const seedOk = !requireSeed || result.actual.seed_present === true;

    const tablesOk =
      result.actual.tables.workflow_app_meta === true &&
      result.actual.tables.workflow_runs === true &&
      result.actual.tables.workflow_events === true &&
      result.actual.tables.pilot_deals === true;

    if (requireSchema && expectedBundleId == null) {
      result.error =
        "Cannot determine expected schema bundle id (missing supabase/bundles/workflow-schema-version.json).";
    } else if (!tablesOk) {
      result.error = "Missing required table(s); apply the SQL bundle.";
    } else if (!schemaOk) {
      result.error = "Schema bundle id mismatch; apply the expected bundle.";
    } else if (!seedOk) {
      result.error = "Required seed row missing; apply the seed/bundle.";
    }

    result.ok = result.error == null;
  } catch (e) {
    result.ok = false;
    result.error = e?.message || String(e);
  } finally {
    try {
      await client.end();
    } catch {
      // ignore
    }
  }

  const outJson = JSON.stringify(result, null, 2) + "\n";
  if (outPath) {
    fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
    fs.writeFileSync(outPath, outJson, "utf8");
  } else {
    process.stdout.write(outJson);
  }

  process.exit(result.ok ? 0 : 2);
}

main().catch((err) => {
  console.error(err?.stack || String(err));
  process.exit(1);
});
