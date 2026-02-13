import Link from "next/link";

export default function QuestionnairePage({
  params,
}: {
  params: { id: string };
}) {
  return (
    <div className="grid">
      <div className="card">
        <h1>Questionnaire {params.id}</h1>
        <p className="muted">
          Workflow: ingest {"->"} draft (citations required) {"->"} approval (human required) {"->"} export.
        </p>
      </div>
      <div className="card">
        <h2>Actions</h2>
        <ul>
          <li>
            <Link href={`/questionnaires/${params.id}/draft`}>Draft review</Link>
          </li>
          <li>
            <Link href={`/questionnaires/${params.id}/approval`}>Approval + export</Link>
          </li>
        </ul>
      </div>
    </div>
  );
}
