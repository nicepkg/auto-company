---
name: team
description: "Assemble and run a temporary multi-role team using dedicated Codex prompts per role. Use when a task benefits from 2-5 specialist roles from .claude/agents/."
argument-hint: "[task description]"
disable-model-invocation: true
---

# Codex Team Orchestration Skill

Use this skill to execute role-based parallel work with dedicated Codex prompt files and role-specific runs.

## Task

$ARGUMENTS

## Role Source

Agent role definitions live in `.claude/agents/`.

## Mandatory Runtime Design

For each role run, you must:
- use a **dedicated prompt file**
- run `codex exec` (not raw API calls)
- set model to `gpt-5.3-codex`
- set reasoning effort to `high`
- run with full access mode (`--dangerously-bypass-approvals-and-sandbox`)
- capture both final response and JSONL event stream

## Execution Steps

### 1. Select a focused team (2-5 roles)

Pick only roles needed for the task. Avoid role overlap.

### 2. Prepare run workspace

```bash
RUN_TS="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="logs/team/$RUN_TS"
mkdir -p "$RUN_DIR"
```

### 3. Spawn one dedicated Codex run per role

For each selected role `<role_id>`:

1. Load role profile from `.claude/agents/<role_id>.md`
2. Build a dedicated prompt file:

```bash
ROLE="<role_id>"
PROMPT_FILE="$RUN_DIR/${ROLE}.prompt.md"
FINAL_FILE="$RUN_DIR/${ROLE}.final.txt"
EVENTS_FILE="$RUN_DIR/${ROLE}.events.jsonl"

cat > "$PROMPT_FILE" <<'PROMPT'
You are running as role: <role_id>.

[Insert full role profile from .claude/agents/<role_id>.md]

Task:
$ARGUMENTS

Requirements:
- Execute from your role perspective.
- Produce concrete deliverables, not generic discussion.
- Write role output to docs/<mapped-role-dir>/.
- End with a concise "Next Action" for handoff.
PROMPT
```

3. Execute the role run:

```bash
codex exec - \
  --model gpt-5.3-codex \
  --json \
  --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  -c 'reasoning.effort="high"' \
  -c 'model_reasoning_effort="high"' \
  -o "$FINAL_FILE" \
  < "$PROMPT_FILE" > "$EVENTS_FILE"
```

### 4. Synthesize and decide

After all role runs finish:
- read each `${ROLE}.final.txt`
- merge into one decision-quality synthesis
- explicitly resolve conflicts with rationale
- produce one owner + one immediate next action

### 5. Persist outputs

- role artifacts must be in `docs/<role>/`
- orchestration records remain in `logs/team/<timestamp>/`

## Role Directory Mapping

| Role ID | Output Directory |
|---|---|
| `ceo-bezos` | `docs/ceo/` |
| `cto-vogels` | `docs/cto/` |
| `critic-munger` | `docs/critic/` |
| `product-norman` | `docs/product/` |
| `ui-duarte` | `docs/ui/` |
| `interaction-cooper` | `docs/interaction/` |
| `fullstack-dhh` | `docs/fullstack/` |
| `qa-bach` | `docs/qa/` |
| `devops-hightower` | `docs/devops/` |
| `marketing-godin` | `docs/marketing/` |
| `operations-pg` | `docs/operations/` |
| `sales-ross` | `docs/sales/` |
| `cfo-campbell` | `docs/cfo/` |
| `research-thompson` | `docs/research/` |

## Guardrails

- Do not ask for API keys; use the logged-in Codex CLI session.
- Keep prompts role-specific and task-specific.
- Keep teams temporary and minimal.
- Prefer shipping concrete artifacts over discussion.
