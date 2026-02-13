import { NextResponse } from "next/server";
import { normalizeDraftAnswers } from "@/lib/workflow/normalizers";
import { recordWorkflowEvent, upsertWorkflowRun } from "@/lib/supabase/workflow-repo";
import { readRunJson, runPythonCli, sanitizeRunId } from "@/lib/workflow/runtime";
import { evaluateCitationGate } from "@/lib/workflow/gates";
import type { DraftPayload } from "@/lib/workflow/types";

type DraftBody = {
  runId: string;
};

export async function POST(request: Request) {
  let body: DraftBody;
  try {
    body = (await request.json()) as DraftBody;
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON body" }, { status: 400 });
  }

  let runId: string;
  try {
    runId = sanitizeRunId(body.runId);
  } catch (error) {
    return NextResponse.json({ ok: false, error: (error as Error).message }, { status: 400 });
  }

  const draftResult = await runPythonCli(["draft", "--run-id", runId], {
    allowNonZeroExit: true
  });

  try {
    const payload = await readRunJson<DraftPayload>(runId, "draft_answers.json");
    const answers = normalizeDraftAnswers(payload);
    const citationGate = evaluateCitationGate(answers);

    await upsertWorkflowRun({
      runId,
      status: citationGate.ok ? "drafted" : "failed",
      citationGatePassed: citationGate.ok,
      metadata: {
        uncitedQuestionIds: citationGate.uncitedQuestionIds,
        cliExitCode: draftResult.exitCode
      }
    });

    await recordWorkflowEvent({
      runId,
      step: "draft",
      status: citationGate.ok ? "success" : "failed",
      payload: {
        uncitedQuestionIds: citationGate.uncitedQuestionIds,
        cliExitCode: draftResult.exitCode
      }
    });

    const status = citationGate.ok ? 200 : 422;
    return NextResponse.json(
      {
        ok: citationGate.ok,
        runId,
        gateChecks: payload.gate_checks,
        answerCount: answers.length,
        uncitedQuestionIds: citationGate.uncitedQuestionIds,
        cli: {
          exitCode: draftResult.exitCode,
          stdout: draftResult.stdout.trim(),
          stderr: draftResult.stderr.trim()
        }
      },
      { status }
    );
  } catch (error) {
    const message = (error as Error).message;
    await upsertWorkflowRun({ runId, status: "failed", metadata: { failedStep: "draft", message } });
    await recordWorkflowEvent({ runId, step: "draft", status: "failed", payload: { message } });

    return NextResponse.json({ ok: false, error: message }, { status: 400 });
  }
}
