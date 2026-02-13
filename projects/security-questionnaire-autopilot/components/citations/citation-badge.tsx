type CitationBadgeProps = {
  citationCount: number;
};

export function CitationBadge({ citationCount }: CitationBadgeProps) {
  const pass = citationCount > 0;
  return (
    <span
      style={{
        borderRadius: 12,
        padding: "2px 10px",
        fontSize: 12,
        fontWeight: 600,
        color: pass ? "#065f46" : "#991b1b",
        backgroundColor: pass ? "#d1fae5" : "#fee2e2"
      }}
    >
      {pass ? `${citationCount} citations` : "Missing citation"}
    </span>
  );
}
