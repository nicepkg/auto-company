type ApprovalGateProps = {
  approved: boolean;
  reviewer?: string;
  reviewedAt?: string;
};

export function ApprovalGate({ approved, reviewer, reviewedAt }: ApprovalGateProps) {
  return (
    <section
      style={{
        border: "1px solid #e5e7eb",
        borderRadius: 8,
        padding: 16,
        backgroundColor: approved ? "#f0fdf4" : "#fff7ed"
      }}
    >
      <h3 style={{ marginTop: 0 }}>Human Approval Gate</h3>
      <p style={{ marginBottom: 0 }}>
        {approved
          ? `Approved by ${reviewer ?? "unknown reviewer"} at ${reviewedAt ?? "unknown time"}.`
          : "Export is blocked until a human reviewer approves all answers."}
      </p>
    </section>
  );
}
