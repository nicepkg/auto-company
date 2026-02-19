import { NextResponse } from "next/server";
import os from "node:os";
import path from "node:path";
import { normalizeApprovalDecisions, normalizeDraftAnswers } from "@/lib/workflow/normalizers";
import { recordWorkflowEvent, upsertWorkflowRun } from "@/lib/supabase/workflow-repo";
import { readRunJson, runPythonCli, sanitizeRunId } from "@/lib/workflow/runtime";
import { assertExportReady } from "@/lib/workflow/gates";
import type { ApprovalPayload, DraftPayload } from "@/lib/workflow/types";

type ExportBody = {
  runId: string;
  outputPath?: string;
};

type Manifest = {
  exported_at: string;
  answer_count: number;
  reviewer: string;
  gates: {
    all_cited: boolean;
    human_approved: boolean;
  };
};

export async function POST(request: Request) {
  let body: ExportBody;
  try {
    body = (await request.json()) as ExportBody;
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON body" }, { status: 400 });
  }

  let runId: string;
  try {
    runId = sanitizeRunId(body.runId);
  } catch (error) {
    return NextResponse.json({ ok: false, error: (error as Error).message }, { status: 400 });
  }

  const outputPath = body.outputPath?.trim() || path.join(os.tmpdir(), `${runId}-hosted-export.zip`);

  try {
    let draft: DraftPayload;
    let approval: ApprovalPayload;
    try {
      draft = await readRunJson<DraftPayload>(runId, "draft_answers.json");
    } catch {
      throw new Error("Export blocked: missing draft answers for run.");
    }
    try {
      approval = await readRunJson<ApprovalPayload>(runId, "approval.json");
    } catch {
      throw new Error("Export blocked: approval gate not satisfied.");
    }

    assertExportReady({
      answers: normalizeDraftAnswers(draft),
      decisions: normalizeApprovalDecisions(approval)
    });

    const exportResult = await runPythonCli([
      "export",
      "--run-id",
      runId,
      "--output",
      outputPath
    ]);

    const manifest = await readRunJson<Manifest>(runId, "export_package/manifest.json");

    await upsertWorkflowRun({
      runId,
      status: "exported",
      citationGatePassed: manifest.gates.all_cited,
      approvalGatePassed: manifest.gates.human_approved,
      reviewer: manifest.reviewer,
      exportBundlePath: outputPath,
      metadata: {
        answerCount: manifest.answer_count,
        exportedAt: manifest.exported_at
      }
    });
    await recordWorkflowEvent({
      runId,
      step: "export",
      status: "success",
      payload: {
        answerCount: manifest.answer_count,
        outputPath
      }
    });

    return NextResponse.json({
      ok: true,
      runId,
      outputPath,
      manifest,
      message: exportResult.stdout.trim()
    });
  } catch (error) {
    const message = (error as Error).message;
    await upsertWorkflowRun({ runId, status: "failed", metadata: { failedStep: "export", message } });
    await recordWorkflowEvent({ runId, step: "export", status: "failed", payload: { message } });

    return NextResponse.json({ ok: false, error: message }, { status: 422 });
  }
}
