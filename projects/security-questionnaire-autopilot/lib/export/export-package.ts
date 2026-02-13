import type { ApprovalDecision, DraftAnswer } from "@/lib/workflow/types";

export function buildExportPackage(input: {
  runId: string;
  reviewer: string;
  reviewedAt: string;
  answers: DraftAnswer[];
  decisions: ApprovalDecision[];
}) {
  const citationsMarkdown = ["# Citation Index", ""];

  for (const answer of input.answers) {
    citationsMarkdown.push(`## ${answer.questionId}`);
    for (const citation of answer.citations) {
      citationsMarkdown.push(
        `- ${citation.source_file}:${citation.line_start}-${citation.line_end}` +
          (citation.quote ? ` | ${citation.quote}` : "")
      );
    }
    citationsMarkdown.push("");
  }

  const answerRows = input.answers.map((item) => ({
    question_id: item.questionId,
    answer: item.answer,
    citations: item.citations
      .map((citation) => `${citation.source_file}:${citation.line_start}-${citation.line_end}`)
      .join("; ")
  }));

  const manifest = {
    run_id: input.runId,
    exported_at: new Date().toISOString(),
    reviewer: input.reviewer,
    approval_timestamp: input.reviewedAt,
    answer_count: input.answers.length,
    approvals: input.decisions,
    gates: {
      all_cited: true,
      human_approved: true
    }
  };

  return {
    manifest,
    answers: answerRows,
    citationsMarkdown: citationsMarkdown.join("\n")
  };
}
