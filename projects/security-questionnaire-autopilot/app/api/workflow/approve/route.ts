import { NextResponse } from "next/server";
import { normalizeApprovalDecisions } from "@/lib/workflow/normalizers";
import { recordWorkflowEvent, upsertWorkflowRun } from "@/lib/supabase/workflow-repo";
import {
  readRunJson,
  runPythonCli,
  sanitizeRunId,
  withTempDir,
  writeTempFile
} from "@/lib/workflow/runtime";
import { evaluateApprovalGate } from "@/lib/workflow/gates";
import type { ApprovalPayload } from "@/lib/workflow/types";

type DecisionInput = {
  questionId: string;
  decision: string;
  notes?: string;
};

type ApproveBody = {
  runId: string;
  reviewer: string;
  decisions: DecisionInput[];
};

function toDecisionCsv(decisions: DecisionInput[]): string {
  const header = "question_id,decision,notes";
  const rows = decisions.map((item) => {
    const notes = (item.notes ?? "").replaceAll('"', '""');
    return `${item.questionId},${item.decision},"${notes}"`;
  });
  return [header, ...rows].join("\n") + "\n";
}

export async function POST(request: Request) {
  let body: ApproveBody;
  try {
    body = (await request.json()) as ApproveBody;
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON body" }, { status: 400 });
  }

  let runId: string;
  try {
    runId = sanitizeRunId(body.runId);
  } catch (error) {
    return NextResponse.json({ ok: false, error: (error as Error).message }, { status: 400 });
  }

  if (!body.reviewer?.trim()) {
    return NextResponse.json({ ok: false, error: "reviewer is required" }, { status: 400 });
  }
  if (!Array.isArray(body.decisions) || body.decisions.length === 0) {
    return NextResponse.json({ ok: false, error: "decisions are required" }, { status: 400 });
  }

  try {
    const approveResult = await withTempDir(runId, async (tempDir) => {
      const csv = toDecisionCsv(body.decisions);
      const decisionsPath = await writeTempFile(tempDir, "approval-decisions.csv", csv);

      return runPythonCli(
        [
          "approve",
          "--run-id",
          runId,
          "--reviewer",
          body.reviewer.trim(),
          "--decisions",
          decisionsPath
        ],
        { allowNonZeroExit: true }
      );
    });

    if (approveResult.exitCode !== 0) {
      await upsertWorkflowRun({
        runId,
        status: "failed",
        metadata: { failedStep: "approve", stderr: approveResult.stderr.trim() }
      });
      await recordWorkflowEvent({
        runId,
        step: "approve",
        status: "failed",
        payload: {
          stderr: approveResult.stderr.trim(),
          stdout: approveResult.stdout.trim()
        }
      });

      return NextResponse.json(
        {
          ok: false,
          error: approveResult.stderr.trim() || approveResult.stdout.trim() || "Approval failed"
        },
        { status: 422 }
      );
    }

    const approval = await readRunJson<ApprovalPayload>(runId, "approval.json");
    const decisions = normalizeApprovalDecisions(approval);
    const approvalGate = evaluateApprovalGate(decisions);

    await upsertWorkflowRun({
      runId,
      status: approvalGate.ok ? "approved" : "failed",
      approvalGatePassed: approvalGate.ok,
      reviewer: approval.reviewer,
      metadata: {
        unresolvedQuestionIds: approvalGate.unresolvedQuestionIds,
        reviewedAt: approval.reviewed_at
      }
    });
    await recordWorkflowEvent({
      runId,
      step: "approve",
      status: approvalGate.ok ? "success" : "failed",
      payload: {
        unresolvedQuestionIds: approvalGate.unresolvedQuestionIds,
        reviewedAt: approval.reviewed_at
      }
    });

    const status = approvalGate.ok ? 200 : 422;
    return NextResponse.json(
      {
        ok: approvalGate.ok,
        runId,
        reviewedAt: approval.reviewed_at,
        reviewer: approval.reviewer,
        unresolvedQuestionIds: approvalGate.unresolvedQuestionIds
      },
      { status }
    );
  } catch (error) {
    const message = (error as Error).message;
    await upsertWorkflowRun({ runId, status: "failed", metadata: { failedStep: "approve", message } });
    await recordWorkflowEvent({ runId, step: "approve", status: "failed", payload: { message } });

    return NextResponse.json({ ok: false, error: message }, { status: 400 });
  }
}
