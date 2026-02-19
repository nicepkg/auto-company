#!/usr/bin/env node
/**
 * Append a DB persistence evidence entry into the Cycle 003 sales execution ledger.
 *
 * This is intentionally small and deterministic so ops can run a single wrapper
 * script and reliably "attach evidence" without manual copy/paste mistakes.
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

function usage(exitCode) {
  console.error(
    [
      "Usage:",
      "  node scripts/append-supabase-evidence-to-sales-doc.mjs --run-id <id> --evidence <file> [--doc <md-file>] [--base-url <url>] [--env-health <json>] [--supabase-health <json>]",
      "",
      "Example:",
      "  node scripts/append-supabase-evidence-to-sales-doc.mjs \\",
      "    --run-id pilot-001-customer-originated-db-20260213-123456 \\",
      "    --evidence /home/zjohn/autocomp/auto-company/docs/devops/cycle-005-supabase-persistence-<run_id>.json"
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

function safeStr(v) {
  if (v === null || v === undefined) return "";
  return String(v);
}

function summarizeEvidence(absPath) {
  const raw = fs.readFileSync(absPath, "utf8");
  const json = JSON.parse(raw);
  const runRow = json?.workflow_runs ?? json?.workflowRun ?? null;
  const eventsRaw = json?.workflow_events ?? json?.workflowEvents ?? [];
  const events = Array.isArray(eventsRaw) ? eventsRaw : [];
  const steps = Array.from(new Set(events.map((e) => safeStr(e?.step)).filter(Boolean))).sort();
  const meta = runRow?.metadata ?? {};

  return {
    runRowPresent: Boolean(runRow),
    runStatus: safeStr(runRow?.status),
    eventCount: events.length,
    steps,
    schemaBundleId: safeStr(meta?.schema_bundle_id),
    schemaBundleSha256: safeStr(meta?.schema_bundle_sha256)
  };
}

const runId = getArg("--run-id");
const evidencePath = getArg("--evidence");
const baseUrl = getArg("--base-url");
const envHealthPath = getArg("--env-health");
const supabaseHealthPath = getArg("--supabase-health");
const docPath =
  getArg("--doc") ||
  path.resolve(process.cwd(), "..", "..", "docs", "sales", "cycle-003-hosted-workflow-pilot-001-execution.md");

if (!runId || !evidencePath) usage(2);

const evidenceAbs = path.resolve(process.cwd(), evidencePath);
const docAbs = path.resolve(process.cwd(), docPath);

if (!fs.existsSync(evidenceAbs)) {
  console.error(`Evidence JSON not found: ${evidenceAbs}`);
  process.exit(2);
}
if (!fs.existsSync(docAbs)) {
  console.error(`Sales doc not found: ${docAbs}`);
  process.exit(2);
}

const evidenceSha = sha256File(evidenceAbs);
const summary = summarizeEvidence(evidenceAbs);
const now = new Date().toISOString();
const evidenceRel = path.relative(path.dirname(docAbs), evidenceAbs);

function tryReadJson(absPath) {
  try {
    return JSON.parse(fs.readFileSync(absPath, "utf8"));
  } catch {
    return null;
  }
}

function maybeShaAndRel(p) {
  if (!p) return null;
  const abs = path.resolve(process.cwd(), p);
  if (!fs.existsSync(abs)) return null;
  return {
    rel: path.relative(path.dirname(docAbs), abs),
    sha256: sha256File(abs),
    json: tryReadJson(abs)
  };
}

const envHealth = maybeShaAndRel(envHealthPath);
const supabaseHealth = maybeShaAndRel(supabaseHealthPath);
const schema =
  supabaseHealth?.json?.schema
    ? {
        required: Boolean(supabaseHealth.json.schema.required),
        expected_schema_bundle_id: safeStr(supabaseHealth.json.schema.expected_schema_bundle_id),
        actual_schema_bundle_id: safeStr(supabaseHealth.json.schema.actual_schema_bundle_id)
      }
    : null;

let doc = fs.readFileSync(docAbs, "utf8");

const sectionHeader = "## Cycle 005 DB Persistence Evidence Log";
if (doc.includes(`run_id=${runId}`)) {
  process.stdout.write(`Sales doc already contains run_id=${runId} in the evidence log; no changes.\n`);
  process.exit(0);
}

function ensureSectionExists(md) {
  if (md.includes(sectionHeader)) return md;
  return (
    md.replace(/\s*$/, "") +
    "\n\n" +
    sectionHeader +
    "\n\n" +
    "Append-only log. Each entry links a hosted run ID to a concrete `workflow_runs` + `workflow_events` evidence artifact.\n"
  );
}

function insertIntoSection(md, entryMd) {
  const lines = md.replace(/\s*$/, "").split("\n");
  const headerIdx = lines.findIndex((l) => l.trim() === sectionHeader);
  if (headerIdx === -1) {
    // Should not happen if ensureSectionExists ran, but be defensive.
    return md.replace(/\s*$/, "") + "\n\n" + entryMd.replace(/^\s*\n/, "");
  }

  let insertIdx = lines.length;
  for (let i = headerIdx + 1; i < lines.length; i++) {
    if (lines[i].startsWith("## ")) {
      insertIdx = i;
      break;
    }
  }

  const entryLines = entryMd.replace(/\s*$/, "").split("\n");
  // Ensure one blank line before the entry (within the section).
  if (insertIdx > 0 && lines[insertIdx - 1].trim() !== "") {
    entryLines.unshift("");
  }
  // Ensure one blank line after the entry if we are inserting before another header.
  if (insertIdx < lines.length && lines[insertIdx].trim() !== "") {
    entryLines.push("");
  }

  lines.splice(insertIdx, 0, ...entryLines);
  return lines.join("\n").replace(/\s*$/, "") + "\n";
}

function kvLine(k, v) {
  if (!v) return null;
  return `${k}=${v}`;
}

const kv = [
  kvLine("run_id", runId),
  kvLine("base_url", baseUrl ? safeStr(baseUrl) : null),
  kvLine("evidence", evidenceRel),
  kvLine("evidence_sha256", evidenceSha),
  kvLine("env_health", envHealth?.rel),
  kvLine("env_health_sha256", envHealth?.sha256),
  kvLine("supabase_health", supabaseHealth?.rel),
  kvLine("supabase_health_sha256", supabaseHealth?.sha256),
  kvLine("schema_expected_bundle_id", schema?.expected_schema_bundle_id),
  kvLine("schema_actual_bundle_id", schema?.actual_schema_bundle_id),
  kvLine("workflow_runs_present", String(summary.runRowPresent)),
  kvLine("workflow_runs_status", summary.runStatus || "unknown"),
  kvLine("workflow_events_count", String(summary.eventCount)),
  kvLine("workflow_event_steps", summary.steps.join(",")),
  kvLine("workflow_runs_schema_bundle_id", summary.schemaBundleId || null),
  kvLine("workflow_runs_schema_bundle_sha256", summary.schemaBundleSha256 || null)
].filter(Boolean);

const entry =
  `### ${now} run_id=${runId}\n\n` +
  "```text\n" +
  kv.join("\n") +
  "\n```\n";

doc = ensureSectionExists(doc);
doc = insertIntoSection(doc, entry);

fs.writeFileSync(docAbs, doc, "utf8");
process.stdout.write(`Appended evidence entry to: ${docAbs}\n`);
