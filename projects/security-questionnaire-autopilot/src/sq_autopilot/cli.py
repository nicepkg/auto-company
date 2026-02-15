from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

PROJECT_ROOT = Path(__file__).resolve().parents[2]
RUNS_DIR = PROJECT_ROOT / "runs"

PRICING_FLOOR = {
    "onboarding_fee": 2000,
    "monthly_fee": 1800,
    "included_questionnaires": 12,
    "overage_fee": 150,
    "gross_margin_floor": 0.70,
}


@dataclass
class SourceChunk:
    source_file: str
    line_start: int
    line_end: int
    text: str


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def tokenize(text: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", text.lower()))


def load_questionnaire_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Questionnaire file not found: {path}")

    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        expected = {"question_id", "question"}
        if not expected.issubset(set(reader.fieldnames or [])):
            raise ValueError(
                "Questionnaire CSV must include columns: question_id,question"
            )

        rows = []
        for row in reader:
            question_id = (row.get("question_id") or "").strip()
            question = (row.get("question") or "").strip()
            if not question_id or not question:
                continue
            rows.append({"question_id": question_id, "question": question})

    if not rows:
        raise ValueError("Questionnaire CSV is empty after parsing")

    return rows


def extract_chunks(source_path: Path) -> list[SourceChunk]:
    text = source_path.read_text(encoding="utf-8")
    chunks: list[SourceChunk] = []
    for line_no, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        chunks.append(
            SourceChunk(
                source_file=source_path.name,
                line_start=line_no,
                line_end=line_no,
                text=line,
            )
        )
    return chunks


def ensure_run_dir(run_id: str) -> Path:
    run_dir = RUNS_DIR / run_id
    if run_dir.exists():
        raise FileExistsError(
            f"Run '{run_id}' already exists at {run_dir}. Use a new run id."
        )
    run_dir.mkdir(parents=True, exist_ok=False)
    (run_dir / "sources").mkdir(parents=True, exist_ok=False)
    return run_dir


def load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Expected file not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def score_chunk(question_tokens: set[str], chunk: SourceChunk) -> float:
    chunk_tokens = tokenize(chunk.text)
    if not chunk_tokens:
        return 0.0
    overlap = len(question_tokens.intersection(chunk_tokens))
    if overlap == 0:
        return 0.0
    # Jaccard overlap with slight reward for dense overlap.
    return overlap / len(question_tokens.union(chunk_tokens)) + (overlap * 0.01)


def top_chunks_for_question(question: str, chunks: Iterable[SourceChunk]) -> list[SourceChunk]:
    q_tokens = tokenize(question)
    ranked = sorted(
        ((score_chunk(q_tokens, chunk), chunk) for chunk in chunks),
        key=lambda pair: pair[0],
        reverse=True,
    )
    return [chunk for score, chunk in ranked if score > 0][:3]


def draft_answer_from_chunks(question: str, ranked_chunks: list[SourceChunk]) -> str:
    if not ranked_chunks:
        return ""
    snippets = [chunk.text for chunk in ranked_chunks[:2]]
    answer = " ".join(snippets)
    if len(answer) > 600:
        return answer[:597].rstrip() + "..."
    return answer


def cmd_ingest(args: argparse.Namespace) -> int:
    run_dir = ensure_run_dir(args.run_id)
    questionnaire = load_questionnaire_csv(Path(args.questionnaire))

    questionnaire_out = run_dir / "questionnaire.csv"
    with questionnaire_out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["question_id", "question"])
        writer.writeheader()
        writer.writerows(questionnaire)

    chunks: list[SourceChunk] = []
    for index, src in enumerate(args.sources, start=1):
        source_path = Path(src)
        if not source_path.exists():
            raise FileNotFoundError(f"Source file not found: {source_path}")
        if source_path.suffix.lower() not in {".md", ".txt", ".csv"}:
            raise ValueError(
                f"Unsupported source file type for {source_path}. Use .md/.txt/.csv"
            )

        destination = run_dir / "sources" / f"{index:02d}_{source_path.name}"
        shutil.copy2(source_path, destination)
        chunks.extend(extract_chunks(destination))

    if not chunks:
        raise ValueError("No source chunks extracted. Check source files.")

    index_payload = {
        "run_id": args.run_id,
        "created_at": now_iso(),
        "chunk_count": len(chunks),
        "chunks": [chunk.__dict__ for chunk in chunks],
    }
    (run_dir / "source_index.json").write_text(
        json.dumps(index_payload, indent=2), encoding="utf-8"
    )

    print(f"Ingest complete for run {args.run_id}")
    print(f"Questions: {len(questionnaire)} | Source chunks: {len(chunks)}")
    return 0


def cmd_draft(args: argparse.Namespace) -> int:
    run_dir = RUNS_DIR / args.run_id
    questionnaire = load_questionnaire_csv(run_dir / "questionnaire.csv")
    index_payload = load_json(run_dir / "source_index.json")
    chunks = [SourceChunk(**chunk) for chunk in index_payload["chunks"]]

    answers = []
    uncited_questions: list[str] = []
    for item in questionnaire:
        ranked = top_chunks_for_question(item["question"], chunks)
        answer = draft_answer_from_chunks(item["question"], ranked)
        citations = [
            {
                "source_file": chunk.source_file,
                "line_start": chunk.line_start,
                "line_end": chunk.line_end,
                "quote": chunk.text[:180],
            }
            for chunk in ranked
        ]
        if not citations:
            uncited_questions.append(item["question_id"])

        answers.append(
            {
                "question_id": item["question_id"],
                "question": item["question"],
                "answer": answer,
                "citations": citations,
                "status": "draft",
            }
        )

    payload = {
        "run_id": args.run_id,
        "generated_at": now_iso(),
        "answers": answers,
        "gate_checks": {
            "all_answers_have_citations": len(uncited_questions) == 0,
            "pending_human_approval": True,
            "uncited_question_ids": uncited_questions,
        },
    }
    (run_dir / "draft_answers.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )

    if uncited_questions:
        print("Draft blocked: uncited answers found")
        print("Uncited question IDs: " + ", ".join(uncited_questions))
        return 1

    print(f"Draft complete for run {args.run_id}")
    print(f"Drafted answers: {len(answers)} (all cited)")
    return 0


def load_decisions_csv(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Decisions file not found: {path}")

    decisions: dict[str, dict[str, str]] = {}
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        expected = {"question_id", "decision", "notes"}
        if not expected.issubset(set(reader.fieldnames or [])):
            raise ValueError(
                "Decisions CSV must include columns: question_id,decision,notes"
            )

        for row in reader:
            question_id = (row.get("question_id") or "").strip()
            decision = (row.get("decision") or "").strip().lower()
            notes = (row.get("notes") or "").strip()
            if not question_id:
                continue
            decisions[question_id] = {
                "question_id": question_id,
                "decision": decision,
                "notes": notes,
            }

    return decisions


def cmd_approve(args: argparse.Namespace) -> int:
    run_dir = RUNS_DIR / args.run_id
    draft_payload = load_json(run_dir / "draft_answers.json")

    if not draft_payload["gate_checks"].get("all_answers_have_citations", False):
        raise ValueError("Cannot approve run with uncited answers.")

    decisions = load_decisions_csv(Path(args.decisions))

    question_ids = [item["question_id"] for item in draft_payload["answers"]]
    missing = [qid for qid in question_ids if qid not in decisions]
    if missing:
        raise ValueError("Missing decisions for question IDs: " + ", ".join(missing))

    rejected = [
        qid
        for qid in question_ids
        if decisions[qid]["decision"] not in {"approve", "approved"}
    ]
    if rejected:
        print("Approval blocked: all questions must be approved before export")
        print("Rejected or unresolved question IDs: " + ", ".join(rejected))
        return 1

    approval_payload = {
        "run_id": args.run_id,
        "reviewer": args.reviewer,
        "reviewed_at": now_iso(),
        "all_approved": True,
        "approvals": [decisions[qid] for qid in question_ids],
    }
    (run_dir / "approval.json").write_text(
        json.dumps(approval_payload, indent=2), encoding="utf-8"
    )

    print(f"Approval recorded for run {args.run_id} by {args.reviewer}")
    return 0


def cmd_export(args: argparse.Namespace) -> int:
    run_dir = RUNS_DIR / args.run_id
    draft_payload = load_json(run_dir / "draft_answers.json")
    approval_payload = load_json(run_dir / "approval.json")

    if not draft_payload["gate_checks"].get("all_answers_have_citations", False):
        raise ValueError("Export blocked: uncited answers present.")

    if not approval_payload.get("all_approved", False):
        raise ValueError("Export blocked: approval gate not satisfied.")

    answers = draft_payload["answers"]
    for answer in answers:
        if not answer.get("citations"):
            raise ValueError(
                f"Export blocked: answer {answer['question_id']} missing citations"
            )

    export_dir = run_dir / "export_package"
    if export_dir.exists():
        shutil.rmtree(export_dir)
    export_dir.mkdir(parents=True, exist_ok=False)

    answers_csv = export_dir / "answers.csv"
    with answers_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["question_id", "question", "answer", "citations"],
        )
        writer.writeheader()
        for answer in answers:
            citation_text = "; ".join(
                f"{c['source_file']}:{c['line_start']}-{c['line_end']}"
                for c in answer["citations"]
            )
            writer.writerow(
                {
                    "question_id": answer["question_id"],
                    "question": answer["question"],
                    "answer": answer["answer"],
                    "citations": citation_text,
                }
            )

    citations_md = export_dir / "citations.md"
    lines = ["# Citation Index", ""]
    for answer in answers:
        lines.append(f"## {answer['question_id']}")
        lines.append(answer["question"])
        for citation in answer["citations"]:
            lines.append(
                f"- {citation['source_file']}:{citation['line_start']}-{citation['line_end']}"
                f" | {citation['quote']}"
            )
        lines.append("")
    citations_md.write_text("\n".join(lines), encoding="utf-8")

    manifest = {
        "run_id": args.run_id,
        "exported_at": now_iso(),
        "reviewer": approval_payload["reviewer"],
        "approval_timestamp": approval_payload["reviewed_at"],
        "answer_count": len(answers),
        "gates": {
            "all_cited": True,
            "human_approved": True,
        },
    }
    (export_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )

    shutil.copy2(run_dir / "questionnaire.csv", export_dir / "questionnaire.csv")
    shutil.copytree(run_dir / "sources", export_dir / "sources")

    output_zip = Path(args.output)
    output_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for file_path in export_dir.rglob("*"):
            if file_path.is_file():
                bundle.write(file_path, arcname=file_path.relative_to(export_dir))

    print(f"Export complete: {output_zip}")
    return 0


def cmd_validate_pilot_deal(args: argparse.Namespace) -> int:
    issues: list[str] = []

    if args.onboarding_fee < PRICING_FLOOR["onboarding_fee"]:
        issues.append(
            f"Onboarding fee below floor (${PRICING_FLOOR['onboarding_fee']})."
        )
    if args.monthly_fee < PRICING_FLOOR["monthly_fee"]:
        issues.append(f"Monthly fee below floor (${PRICING_FLOOR['monthly_fee']}).")
    if args.included_questionnaires > PRICING_FLOOR["included_questionnaires"]:
        issues.append(
            "Included questionnaires exceed floor package limit (12), hurting margin."
        )
    if args.overage_fee < PRICING_FLOOR["overage_fee"]:
        issues.append(f"Overage fee below floor (${PRICING_FLOOR['overage_fee']}).")

    revenue = args.monthly_fee + max(
        0, args.expected_questionnaires - args.included_questionnaires
    ) * args.overage_fee
    cogs = args.expected_questionnaires * args.estimated_cogs_per_questionnaire
    gross_margin = 0.0 if revenue == 0 else (revenue - cogs) / revenue

    if gross_margin < PRICING_FLOOR["gross_margin_floor"]:
        issues.append(
            "Projected gross margin below floor "
            f"({PRICING_FLOOR['gross_margin_floor'] * 100:.0f}%)."
        )

    result = {
        "pricing_floor": PRICING_FLOOR,
        "deal": {
            "onboarding_fee": args.onboarding_fee,
            "monthly_fee": args.monthly_fee,
            "included_questionnaires": args.included_questionnaires,
            "overage_fee": args.overage_fee,
            "expected_questionnaires": args.expected_questionnaires,
            "estimated_cogs_per_questionnaire": args.estimated_cogs_per_questionnaire,
        },
        "projection": {
            "monthly_revenue": revenue,
            "monthly_cogs": cogs,
            "gross_margin": round(gross_margin, 4),
        },
        "approved": len(issues) == 0,
        "issues": issues,
    }

    print(json.dumps(result, indent=2))
    return 0 if not issues else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="sq-autopilot",
        description="Security Questionnaire Autopilot MVP",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    ingest = subparsers.add_parser(
        "ingest", help="Create a run and ingest questionnaire + evidence sources"
    )
    ingest.add_argument("--run-id", required=True, help="Unique run id")
    ingest.add_argument(
        "--questionnaire", required=True, help="CSV with question_id,question"
    )
    ingest.add_argument(
        "--sources",
        required=True,
        nargs="+",
        help="One or more source files (.md/.txt/.csv)",
    )
    ingest.set_defaults(func=cmd_ingest)

    draft = subparsers.add_parser(
        "draft", help="Generate source-grounded draft answers with citations"
    )
    draft.add_argument("--run-id", required=True)
    draft.set_defaults(func=cmd_draft)

    approve = subparsers.add_parser(
        "approve", help="Apply mandatory human approval decisions"
    )
    approve.add_argument("--run-id", required=True)
    approve.add_argument("--reviewer", required=True)
    approve.add_argument(
        "--decisions",
        required=True,
        help="CSV with question_id,decision,notes",
    )
    approve.set_defaults(func=cmd_approve)

    export = subparsers.add_parser(
        "export", help="Export approved answers bundle"
    )
    export.add_argument("--run-id", required=True)
    export.add_argument("--output", required=True, help="Zip output path")
    export.set_defaults(func=cmd_export)

    validate = subparsers.add_parser(
        "validate-pilot-deal",
        help="Enforce pricing floor + margin gate for design partner deals",
    )
    validate.add_argument("--onboarding-fee", type=float, required=True)
    validate.add_argument("--monthly-fee", type=float, required=True)
    validate.add_argument("--included-questionnaires", type=int, required=True)
    validate.add_argument("--overage-fee", type=float, required=True)
    validate.add_argument("--expected-questionnaires", type=int, required=True)
    validate.add_argument(
        "--estimated-cogs-per-questionnaire",
        type=float,
        required=True,
    )
    validate.set_defaults(func=cmd_validate_pilot_deal)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    RUNS_DIR.mkdir(parents=True, exist_ok=True)

    try:
        return args.func(args)
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
