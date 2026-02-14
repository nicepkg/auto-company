import { NextResponse } from "next/server";
import path from "node:path";
import {
  readRunJson,
  runPythonCli,
  sanitizeRunId,
  templateFile,
  withTempDir,
  writeTempFile
} from "@/lib/workflow/runtime";
import { recordWorkflowEvent, upsertWorkflowRun } from "@/lib/supabase/workflow-repo";

type SourceInput = {
  fileName: string;
  content: string;
};

type IngestBody = {
  runId: string;
  questionnaireCsv?: string;
  sources?: SourceInput[];
};

type SourceIndex = {
  chunk_count: number;
};

export async function POST(request: Request) {
  let body: IngestBody;

  try {
    body = (await request.json()) as IngestBody;
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON body" }, { status: 400 });
  }

  let runId: string;
  try {
    runId = sanitizeRunId(body.runId);
  } catch (error) {
    return NextResponse.json({ ok: false, error: (error as Error).message }, { status: 400 });
  }

  try {
    const ingestResult = await withTempDir(runId, async (tempDir) => {
      let questionnairePath = templateFile("questionnaire.template.csv");
      let sourcePaths = [
        templateFile("source-security-policy.md"),
        templateFile("source-incident-response.md")
      ];

      if (body.questionnaireCsv) {
        questionnairePath = await writeTempFile(tempDir, "questionnaire.csv", body.questionnaireCsv);
      }

      if (Array.isArray(body.sources) && body.sources.length > 0) {
        sourcePaths = [];
        for (const source of body.sources) {
          const safeName = path.basename(source.fileName || "source.md");
          sourcePaths.push(await writeTempFile(tempDir, safeName, source.content));
        }
      }

      return runPythonCli([
        "ingest",
        "--run-id",
        runId,
        "--questionnaire",
        questionnairePath,
        "--sources",
        ...sourcePaths
      ]);
    });

    const sourceIndex = await readRunJson<SourceIndex>(runId, "source_index.json");

    await upsertWorkflowRun({
      runId,
      status: "ingested",
      metadata: { chunkCount: sourceIndex.chunk_count }
    });
    await recordWorkflowEvent({
      runId,
      step: "ingest",
      status: "success",
      payload: {
        chunkCount: sourceIndex.chunk_count,
        stdout: ingestResult.stdout.trim()
      }
    });

    return NextResponse.json({
      ok: true,
      runId,
      chunkCount: sourceIndex.chunk_count,
      message: ingestResult.stdout.trim()
    });
  } catch (error) {
    const message = (error as Error).message;
    await upsertWorkflowRun({ runId, status: "failed", metadata: { failedStep: "ingest", message } });
    await recordWorkflowEvent({ runId, step: "ingest", status: "failed", payload: { message } });

    return NextResponse.json({ ok: false, error: message }, { status: 400 });
  }
}
