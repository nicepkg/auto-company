export type Citation = {
  source_file: string;
  line_start: number;
  line_end: number;
  quote?: string;
};

export type DraftAnswer = {
  questionId: string;
  question?: string;
  answer: string;
  citations: Citation[];
  status?: string;
};

export type ApprovalDecision = {
  questionId: string;
  decision: string;
  notes?: string;
};

export type DraftPayload = {
  run_id: string;
  generated_at: string;
  answers: Array<{
    question_id: string;
    question: string;
    answer: string;
    citations: Citation[];
    status: string;
  }>;
  gate_checks: {
    all_answers_have_citations: boolean;
    pending_human_approval: boolean;
    uncited_question_ids: string[];
  };
};

export type ApprovalPayload = {
  run_id: string;
  reviewer: string;
  reviewed_at: string;
  all_approved: boolean;
  approvals: Array<{
    question_id: string;
    decision: string;
    notes: string;
  }>;
};
