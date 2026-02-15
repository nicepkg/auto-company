import { CitationBadge } from "@/components/citations/citation-badge";
import { getSupabaseAdminOrNull } from "@/lib/supabase/server";
import { evaluateCitationGate } from "@/lib/workflow/gates";
import type { DraftAnswer } from "@/lib/workflow/types";

export const dynamic = "force-dynamic";

export default async function DraftQuestionnairePage({
  params
}: {
  params: { id: string };
}) {
  const supabase = getSupabaseAdminOrNull();
  if (!supabase) {
    return (
      <main style={{ padding: 24 }}>
        <h1 style={{ marginTop: 0 }}>Draft Review - Run {params.id}</h1>
        <p>Set Supabase environment variables to load hosted draft state.</p>
      </main>
    );
  }

  const { data, error } = await supabase
    .from("questionnaire_drafts")
    .select("question_id,answer,citations")
    .eq("run_id", params.id)
    .order("question_id", { ascending: true });

  if (error) {
    throw new Error(`Failed to load draft data: ${error.message}`);
  }

  const answers: DraftAnswer[] = (data ?? []).map((item) => ({
    questionId: item.question_id,
    answer: item.answer,
    citations: Array.isArray(item.citations) ? item.citations : []
  }));

  const gate = evaluateCitationGate(answers);

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ marginTop: 0 }}>Draft Review - Run {params.id}</h1>
      <p>Citation gate status: {gate.ok ? "PASS" : "BLOCKED"}</p>
      {!gate.ok ? (
        <p style={{ color: "#991b1b" }}>
          Uncited question IDs: {gate.uncitedQuestionIds.join(", ")}
        </p>
      ) : null}

      <ul style={{ listStyle: "none", padding: 0, marginTop: 20 }}>
        {answers.map((item) => (
          <li key={item.questionId} style={{ borderBottom: "1px solid #e5e7eb", padding: "12px 0" }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong>{item.questionId}</strong>
              <CitationBadge citationCount={item.citations.length} />
            </div>
            <p style={{ marginBottom: 0 }}>{item.answer}</p>
          </li>
        ))}
      </ul>

      <button
        type="button"
        disabled={!gate.ok}
        style={{
          marginTop: 20,
          border: 0,
          borderRadius: 6,
          padding: "10px 14px",
          background: gate.ok ? "#111827" : "#9ca3af",
          color: "white",
          cursor: gate.ok ? "pointer" : "not-allowed"
        }}
      >
        Queue for Human Approval
      </button>
    </main>
  );
}
