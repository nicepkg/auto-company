#!/usr/bin/env node
/**
 * Validate Supabase DB persistence evidence for a workflow run.
 *
 * Input: JSON produced by scripts/fetch-supabase-workflow-evidence.mjs
 * Output: exits 0 on pass; exits 1 on failure.
 */

import fs from "node:fs";
import process from "node:process";
import path from "node:path";
import { fileURLToPath } from "node:url";

function usage(exitCode) {
  console.error(
    [
      "Usage:",
      "  node scripts/validate-supabase-workflow-evidence.mjs --evidence <file>",
      "",
      "Checks:",
      "  - workflow_runs row exists",
      "  - workflow_runs.status != failed",
      "  - workflow_events includes success for steps ingest,draft,approve,export"
    ].join("\n")
  );
  process.exit(exitCode);
}

function getArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return null;
  return process.argv[idx + 1] ?? null;
}

function safeStr(v) {
  if (v === null || v === undefined) return "";
  return String(v);
}

function fail(msg) {
  process.stderr.write(msg.trimEnd() + "\n");
  process.exit(1);
}

function warn(msg) {
  process.stderr.write(`Warning: ${msg.trimEnd()}\n`);
}

function envBool(name, defaultValue) {
  const raw = process.env[name];
  if (raw == null || raw === "") return defaultValue;
  return raw.toLowerCase() === "true" || raw === "1" || raw.toLowerCase() === "yes";
}

function loadExpectedSchemaOrNull() {
  try {
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const abs = path.resolve(__dirname, "..", "supabase", "bundles", "workflow-schema-version.json");
    return JSON.parse(fs.readFileSync(abs, "utf8"));
  } catch {
    return null;
  }
}

const evidencePath = getArg("--evidence");
if (!evidencePath) usage(2);

let evidence;
try {
  evidence = JSON.parse(fs.readFileSync(evidencePath, "utf8"));
} catch (err) {
  fail(`Invalid JSON evidence file: ${evidencePath}\n${err?.message || String(err)}`);
}

// Accept both shapes:
// - snake_case from fetch-supabase-workflow-evidence.mjs and /api/workflow/db-evidence (preferred)
// - camelCase from legacy fetch-db-evidence.mjs
const runRow = evidence?.workflow_runs ?? evidence?.workflowRun ?? null;
const eventsRaw = evidence?.workflow_events ?? evidence?.workflowEvents ?? [];
const events = Array.isArray(eventsRaw) ? eventsRaw : [];

if (!runRow) {
  fail(`Evidence missing workflow_runs row. evidence=${evidencePath}`);
}

const runId = safeStr(runRow?.run_id) || safeStr(evidence?.runId);
if (!runId) {
  fail(`Evidence missing run_id. evidence=${evidencePath}`);
}

const status = safeStr(runRow?.status);
if (!status) {
  fail(`Evidence workflow_runs.status is empty. run_id=${runId} evidence=${evidencePath}`);
}
if (status === "failed") {
  fail(`Evidence workflow_runs.status=failed. run_id=${runId} evidence=${evidencePath}`);
}

// Optional but recommended: verify schema identity to prevent "evidence against the wrong DB/schema".
// Enforced when REQUIRE_SCHEMA_MATCH=1.
const requireSchemaMatch = envBool("REQUIRE_SCHEMA_MATCH", false);
const expectedSchema = evidence?.expectedSchema ?? loadExpectedSchemaOrNull();
const evidenceMeta = runRow?.metadata ?? {};
const observedBundleSha =
  safeStr(evidenceMeta?.schema_bundle_sha256) ||
  safeStr(evidenceMeta?.schemaBundleSha256) ||
  safeStr(evidenceMeta?.bundleSha256);
const expectedBundleSha = safeStr(expectedSchema?.bundleSha256);

if (expectedBundleSha) {
  if (!observedBundleSha) {
    const msg = `Evidence missing metadata.schema_bundle_sha256 (expected ${expectedBundleSha}). run_id=${runId} evidence=${evidencePath}`;
    if (requireSchemaMatch) fail(msg);
    warn(msg);
  } else if (observedBundleSha !== expectedBundleSha) {
    fail(
      `Schema mismatch: metadata.schema_bundle_sha256=${observedBundleSha} expected=${expectedBundleSha}. run_id=${runId} evidence=${evidencePath}`
    );
  }
} else if (requireSchemaMatch) {
  fail(`Expected schema bundleSha256 not found; cannot enforce schema match. evidence=${evidencePath}`);
}

const requiredSteps = ["ingest", "draft", "approve", "export"];
const successByStep = new Map(requiredSteps.map((s) => [s, false]));

for (const e of events) {
  const step = safeStr(e?.step);
  const s = safeStr(e?.status);
  if (successByStep.has(step) && s === "success") {
    successByStep.set(step, true);
  }
}

const missing = requiredSteps.filter((s) => !successByStep.get(s));
if (missing.length > 0) {
  fail(
    `Evidence missing success workflow_events for step(s): ${missing.join(
      ","
    )}. run_id=${runId} evidence=${evidencePath}`
  );
}

process.stdout.write(
  [
    "DB evidence validation: PASS",
    `run_id=${runId}`,
    `workflow_runs.status=${status}`,
    `workflow_events.count=${events.length}`
  ].join("\n") + "\n"
);
