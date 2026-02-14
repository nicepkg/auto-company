import type { ApprovalDecision, DraftAnswer } from "@/lib/workflow/types";

export const PRICING_FLOOR = Object.freeze({
  onboardingFee: 2000,
  monthlyFee: 1800,
  includedQuestionnaires: 12,
  overageFee: 150,
  grossMarginFloor: 0.7
});

export type PricingGateInput = {
  onboardingFee: number;
  monthlyFee: number;
  includedQuestionnaires: number;
  overageFee: number;
  expectedQuestionnaires: number;
  estimatedCogsPerQuestionnaire: number;
};

export function evaluateCitationGate(answers: DraftAnswer[]) {
  const uncitedQuestionIds = answers
    .filter((item) => !Array.isArray(item.citations) || item.citations.length === 0)
    .map((item) => item.questionId);

  return {
    ok: uncitedQuestionIds.length === 0,
    uncitedQuestionIds
  };
}

export function evaluateApprovalGate(decisions: ApprovalDecision[]) {
  const unresolvedQuestionIds = decisions
    .filter((item) => {
      const normalized = item.decision.trim().toLowerCase();
      return normalized !== "approve" && normalized !== "approved";
    })
    .map((item) => item.questionId);

  return {
    ok: unresolvedQuestionIds.length === 0,
    unresolvedQuestionIds
  };
}

export function evaluatePricingMarginGate(input: PricingGateInput) {
  const issues: string[] = [];

  if (input.onboardingFee < PRICING_FLOOR.onboardingFee) {
    issues.push(`Onboarding fee below floor ($${PRICING_FLOOR.onboardingFee}).`);
  }
  if (input.monthlyFee < PRICING_FLOOR.monthlyFee) {
    issues.push(`Monthly fee below floor ($${PRICING_FLOOR.monthlyFee}).`);
  }
  if (input.includedQuestionnaires > PRICING_FLOOR.includedQuestionnaires) {
    issues.push("Included questionnaires exceed package floor limit (12).");
  }
  if (input.overageFee < PRICING_FLOOR.overageFee) {
    issues.push(`Overage fee below floor ($${PRICING_FLOOR.overageFee}).`);
  }

  const monthlyRevenue =
    input.monthlyFee +
    Math.max(0, input.expectedQuestionnaires - input.includedQuestionnaires) * input.overageFee;

  const monthlyCogs = input.expectedQuestionnaires * input.estimatedCogsPerQuestionnaire;
  const grossMargin = monthlyRevenue === 0 ? 0 : (monthlyRevenue - monthlyCogs) / monthlyRevenue;

  if (grossMargin < PRICING_FLOOR.grossMarginFloor) {
    issues.push(`Projected gross margin below floor (${PRICING_FLOOR.grossMarginFloor * 100}%).`);
  }

  return {
    approved: issues.length === 0,
    issues,
    projection: {
      monthlyRevenue,
      monthlyCogs,
      grossMargin: Number(grossMargin.toFixed(4))
    }
  };
}

export function assertExportReady(input: {
  answers: DraftAnswer[];
  decisions: ApprovalDecision[];
}) {
  const citationGate = evaluateCitationGate(input.answers);
  if (!citationGate.ok) {
    throw new Error(
      `Export blocked: uncited answers for question IDs ${citationGate.uncitedQuestionIds.join(", ")}`
    );
  }

  const approvalGate = evaluateApprovalGate(input.decisions);
  if (!approvalGate.ok) {
    throw new Error(
      `Export blocked: unresolved approvals for question IDs ${approvalGate.unresolvedQuestionIds.join(", ")}`
    );
  }
}
