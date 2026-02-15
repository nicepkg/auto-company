#!/usr/bin/env node
/**
 * Verify the paste-ready Supabase Dashboard SQL bundle matches the current
 * migration/seed files (prevents schema/evidence mismatch due to stale bundle).
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import process from "node:process";

function usage(exitCode) {
  console.error(
    [
      "Usage:",
      "  node scripts/verify-dashboard-sql-bundle.mjs --bundle <file> [--migration <file>] [--seed <file>]",
      "",
      "Defaults:",
      "  --migration supabase/migrations/20260213_cycle003_hosted_workflow.sql",
      "  --seed      supabase/seed/pilot-001-floor-pricing.sql"
    ].join("\n")
  );
  process.exit(exitCode);
}

function getArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return null;
  return process.argv[idx + 1] ?? null;
}

function sha256File(absPath) {
  const buf = fs.readFileSync(absPath);
  return crypto.createHash("sha256").update(buf).digest("hex");
}

function fail(msg) {
  process.stderr.write(msg.trimEnd() + "\n");
  process.exit(1);
}

const bundlePath = getArg("--bundle");
if (!bundlePath) usage(2);

const defaultMigration = "supabase/migrations/20260213_cycle003_hosted_workflow.sql";
const defaultSeed = "supabase/seed/pilot-001-floor-pricing.sql";

const migrationPath = getArg("--migration") || defaultMigration;
const seedPath = getArg("--seed") || defaultSeed;

const bundleAbs = path.resolve(process.cwd(), bundlePath);
const migrationAbs = path.resolve(process.cwd(), migrationPath);
const seedAbs = path.resolve(process.cwd(), seedPath);

if (!fs.existsSync(bundleAbs)) fail(`Bundle not found: ${bundleAbs}`);
if (!fs.existsSync(migrationAbs)) fail(`Migration not found: ${migrationAbs}`);
if (!fs.existsSync(seedAbs)) fail(`Seed not found: ${seedAbs}`);

const bundle = fs.readFileSync(bundleAbs, "utf8");
const m = bundle.match(/^\s*--\s*Source SHA256 \(migration\):\s*([a-f0-9]{64})\s*$/m);
const s = bundle.match(/^\s*--\s*Source SHA256 \(seed\):\s*([a-f0-9]{64})\s*$/m);

if (!m) fail(`Bundle missing migration SHA256 header line. bundle=${bundleAbs}`);
if (!s) fail(`Bundle missing seed SHA256 header line. bundle=${bundleAbs}`);

const expectedMigrationSha = m[1];
const expectedSeedSha = s[1];
const actualMigrationSha = sha256File(migrationAbs);
const actualSeedSha = sha256File(seedAbs);

if (expectedMigrationSha !== actualMigrationSha) {
  fail(
    [
      "Bundle migration SHA mismatch:",
      `bundle=${bundleAbs}`,
      `migration=${migrationAbs}`,
      `expected=${expectedMigrationSha}`,
      `actual=${actualMigrationSha}`
    ].join("\n")
  );
}

if (expectedSeedSha !== actualSeedSha) {
  fail(
    [
      "Bundle seed SHA mismatch:",
      `bundle=${bundleAbs}`,
      `seed=${seedAbs}`,
      `expected=${expectedSeedSha}`,
      `actual=${actualSeedSha}`
    ].join("\n")
  );
}

process.stdout.write(
  [
    "Dashboard SQL bundle verification: PASS",
    `bundle=${bundleAbs}`,
    `migration_sha256=${actualMigrationSha}`,
    `seed_sha256=${actualSeedSha}`
  ].join("\n") + "\n"
);

