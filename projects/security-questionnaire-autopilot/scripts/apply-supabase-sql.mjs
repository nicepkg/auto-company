#!/usr/bin/env node
/**
 * Apply one or more .sql files to a Postgres database (Supabase) using a direct
 * connection string from SUPABASE_DB_URL (or DATABASE_URL).
 *
 * This avoids relying on `psql`/`supabase` CLIs, which may not be installed in
 * constrained environments.
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { Client } from "pg";

function usage() {
  console.error(
    [
      "Usage:",
      "  apply-supabase-sql.mjs <sql-file> [<sql-file> ...]",
      "",
      "Env:",
      "  SUPABASE_DB_URL (preferred) or DATABASE_URL: Postgres connection string",
      "  SUPABASE_DB_SSL: true|false (default: true)",
      "  SUPABASE_DB_SSL_REJECT_UNAUTHORIZED: true|false (default: true)",
      "",
      "Example:",
      "  SUPABASE_DB_URL=... node scripts/apply-supabase-sql.mjs supabase/migrations/20260213_cycle003_hosted_workflow.sql supabase/seed/pilot-001-floor-pricing.sql"
    ].join("\n")
  );
}

function envBool(name, defaultValue) {
  const raw = process.env[name];
  if (raw == null || raw === "") return defaultValue;
  return raw.toLowerCase() === "true" || raw === "1" || raw.toLowerCase() === "yes";
}

async function main() {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    usage();
    process.exit(2);
  }

  const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error("Missing SUPABASE_DB_URL (or DATABASE_URL).");
    usage();
    process.exit(2);
  }

  const sslEnabled = envBool("SUPABASE_DB_SSL", true);
  const sslRejectUnauthorized = envBool("SUPABASE_DB_SSL_REJECT_UNAUTHORIZED", true);

  const client = new Client({
    connectionString,
    ssl: sslEnabled ? { rejectUnauthorized: sslRejectUnauthorized } : undefined
  });

  await client.connect();
  try {
    for (const file of files) {
      const abs = path.resolve(process.cwd(), file);
      if (!fs.existsSync(abs)) {
        throw new Error(`SQL file not found: ${abs}`);
      }

      const sql = fs.readFileSync(abs, "utf8");
      const label = path.relative(process.cwd(), abs);
      process.stdout.write(`Applying ${label}...\n`);

      // Allow multi-statement SQL in a single string.
      await client.query({ text: sql, queryMode: "simple" });
      process.stdout.write(`Applied ${label}\n`);
    }
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err?.stack || String(err));
  process.exit(1);
});

