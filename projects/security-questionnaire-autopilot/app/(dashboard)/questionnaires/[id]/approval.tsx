import { ApprovalGate } from "@/components/approval/approval-gate";
import { getSupabaseAdminOrNull } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function ApprovalQuestionnairePage({
  params
}: {
  params: { id: string };
}) {
  const supabase = getSupabaseAdminOrNull();
  if (!supabase) {
    return (
      <main style={{ padding: 24 }}>
        <h1 style={{ marginTop: 0 }}>Approval - Run {params.id}</h1>
        <p>Set Supabase environment variables to load hosted approval state.</p>
      </main>
    );
  }
  const { data, error } = await supabase
    .from("questionnaire_approvals")
    .select("reviewer,reviewed_at,all_approved")
    .eq("run_id", params.id)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to load approval status: ${error.message}`);
  }

  const approved = Boolean(data?.all_approved);

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ marginTop: 0 }}>Approval - Run {params.id}</h1>
      <ApprovalGate approved={approved} reviewer={data?.reviewer} reviewedAt={data?.reviewed_at} />

      <button
        type="button"
        disabled={!approved}
        style={{
          marginTop: 16,
          border: 0,
          borderRadius: 6,
          padding: "10px 14px",
          background: approved ? "#111827" : "#9ca3af",
          color: "white",
          cursor: approved ? "pointer" : "not-allowed"
        }}
      >
        Export Package
      </button>
    </main>
  );
}
