import { NextResponse } from "next/server";
import { recordWorkflowEvent } from "@/lib/supabase/workflow-repo";
import {
  evaluatePricingMarginGate,
  PRICING_FLOOR,
  type PricingGateInput
} from "@/lib/workflow/gates";

type ValidateBody = PricingGateInput & {
  runId?: string;
};

function toNumber(value: unknown): number {
  if (typeof value === "number") {
    return value;
  }
  return Number(value);
}

export async function POST(request: Request) {
  let body: ValidateBody;
  try {
    body = (await request.json()) as ValidateBody;
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON body" }, { status: 400 });
  }

  const input: PricingGateInput = {
    onboardingFee: toNumber(body.onboardingFee),
    monthlyFee: toNumber(body.monthlyFee),
    includedQuestionnaires: toNumber(body.includedQuestionnaires),
    overageFee: toNumber(body.overageFee),
    expectedQuestionnaires: toNumber(body.expectedQuestionnaires),
    estimatedCogsPerQuestionnaire: toNumber(body.estimatedCogsPerQuestionnaire)
  };

  const hasInvalidNumber = Object.values(input).some((value) => Number.isNaN(value));
  if (hasInvalidNumber) {
    return NextResponse.json({ ok: false, error: "All pricing fields must be numeric" }, { status: 400 });
  }

  const result = evaluatePricingMarginGate(input);

  if (body.runId) {
    await recordWorkflowEvent({
      runId: body.runId,
      step: "validate-pilot-deal",
      status: result.approved ? "success" : "failed",
      payload: {
        projection: result.projection,
        issues: result.issues
      }
    });
  }

  const status = result.approved ? 200 : 422;
  return NextResponse.json(
    {
      ok: result.approved,
      pricingFloor: PRICING_FLOOR,
      deal: input,
      ...result
    },
    { status }
  );
}
