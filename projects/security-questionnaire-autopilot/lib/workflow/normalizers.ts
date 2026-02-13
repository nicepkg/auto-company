import type {
  ApprovalDecision,
  ApprovalPayload,
  DraftAnswer,
  DraftPayload
} from "@/lib/workflow/types";

export function normalizeDraftAnswers(payload: DraftPayload): DraftAnswer[] {
  return payload.answers.map((item) => ({
    questionId: item.question_id,
    question: item.question,
    answer: item.answer,
    citations: Array.isArray(item.citations) ? item.citations : [],
    status: item.status
  }));
}

export function normalizeApprovalDecisions(payload: ApprovalPayload): ApprovalDecision[] {
  return payload.approvals.map((item) => ({
    questionId: item.question_id,
    decision: item.decision,
    notes: item.notes
  }));
}
