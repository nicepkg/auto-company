#!/usr/bin/env node
/**
 * Build a paste-ready SQL bundle for Supabase Dashboard SQL Editor by
 * concatenating migration + seed files with a small header.
 *
 * This keeps the repo's bundle file deterministic and avoids hand-edit drift.
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

function usage(exitCode) {
  console.error(
    [
      "Usage:",
      "  node scripts/build-dashboard-sql-bundle.mjs --migration <file.sql> --seed <file.sql> --out <bundle.sql>",
      "",
      "Example:",
      "  node scripts/build-dashboard-sql-bundle.mjs \\",
      "    --migration supabase/migrations/20260213_cycle003_hosted_workflow.sql \\",
      "    --seed supabase/seed/pilot-001-floor-pricing.sql \\",
      "    --out supabase/bundles/20260213_cycle003_hosted_workflow_migration_plus_seed.sql"
    ].join("\n")
  );
  process.exit(exitCode);
}

function getArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return null;
  return process.argv[idx + 1] ?? null;
}

function sha256(text) {
  return crypto.createHash("sha256").update(text, "utf8").digest("hex");
}

function normalizeSql(content) {
  // Ensure bundle ends with a single trailing newline for stable diffs.
  return content.replace(/\s*$/, "") + "\n";
}

const migrationPath = getArg("--migration");
const seedPath = getArg("--seed");
const outPath = getArg("--out");
if (!migrationPath || !seedPath || !outPath) usage(2);

const migrationAbs = path.resolve(process.cwd(), migrationPath);
const seedAbs = path.resolve(process.cwd(), seedPath);
const outAbs = path.resolve(process.cwd(), outPath);

if (!fs.existsSync(migrationAbs)) {
  console.error(`Migration SQL not found: ${migrationAbs}`);
  process.exit(2);
}
if (!fs.existsSync(seedAbs)) {
  console.error(`Seed SQL not found: ${seedAbs}`);
  process.exit(2);
}

const migrationSql = normalizeSql(fs.readFileSync(migrationAbs, "utf8"));
const seedSql = normalizeSql(fs.readFileSync(seedAbs, "utf8"));

const header = [
  "-- Hosted Workflow: Migration + Seed (Paste-Ready Bundle)",
  "--",
  "-- Purpose:",
  "-- - Paste this entire file into Supabase Dashboard -> SQL Editor and run once.",
  "-- - Keeps migration + seed apply as a single, low-error operation.",
  "--",
  `-- Source files:`,
  `-- - ${path.relative(process.cwd(), migrationAbs)}`,
  `-- - ${path.relative(process.cwd(), seedAbs)}`,
  "--",
  `-- Build: node scripts/build-dashboard-sql-bundle.mjs --migration ... --seed ... --out ...`,
  `-- Source SHA256 (migration): ${sha256(migrationSql)}`,
  `-- Source SHA256 (seed): ${sha256(seedSql)}`,
  ""
].join("\n");

const verify = [
  "-- === VERIFY (OPTIONAL; SAFE TO RUN) ===",
  "-- Confirm tables exist.",
  "select table_name",
  "from information_schema.tables",
  "where table_schema = 'public'",
  "  and table_name in ('workflow_app_meta', 'workflow_runs', 'workflow_events', 'pilot_deals')",
  "order by table_name;",
  "",
  "-- Confirm schema bundle id exists.",
  "select meta_key, meta_value, updated_at",
  "from public.workflow_app_meta",
  "where meta_key = 'schema_bundle_id';",
  "",
  "-- Confirm seed row exists.",
  "select run_id, status, citation_gate_passed, approval_gate_passed, reviewer, created_at, updated_at",
  "from public.workflow_runs",
  "where run_id = 'pilot-001-live-2026-02-13';",
  ""
].join("\n");

const bundle = normalizeSql(
  [
    header,
    "-- === MIGRATION ===",
    migrationSql.trimEnd(),
    "",
    "-- === SEED ===",
    seedSql.trimEnd(),
    "",
    verify
  ].join("\n")
);

fs.mkdirSync(path.dirname(outAbs), { recursive: true });
fs.writeFileSync(outAbs, bundle, "utf8");

// Keep a single "expected schema" descriptor in-sync with the bundle build so:
// - hosted workflow_runs metadata can stamp it (lib/workflow/schema-version.ts)
// - evidence validation can detect schema drift deterministically
const schemaVersionAbs = path.resolve(path.dirname(outAbs), "workflow-schema-version.json");
const schemaVersion = {
  // Prefer the semantic schema ID (migration basename) over the bundle filename.
  bundleId: path.basename(migrationAbs, ".sql"),
  bundleSha256: sha256(bundle),
  migrationSha256: sha256(migrationSql),
  seedSha256: sha256(seedSql)
};
fs.writeFileSync(schemaVersionAbs, JSON.stringify(schemaVersion, null, 2) + "\n", "utf8");

process.stdout.write(`Wrote bundle: ${outAbs}\n`);
process.stdout.write(`Wrote schema version: ${schemaVersionAbs}\n`);
