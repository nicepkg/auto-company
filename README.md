<div align="center">

# Auto Company

**A fully autonomous AI company running 24/7**

14 AI agents, each modeled after a world-class expert in a specific discipline.
They ideate products, make decisions, write code, deploy, and market without human-in-the-loop operations.

Powered by [Codex CLI](https://developers.openai.com/codex/cli) in autonomous loop mode.

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)](#dependencies)
[![Runtime](https://img.shields.io/badge/runtime-Codex%20CLI-orange)](https://developers.openai.com/codex/cli)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](#license)
[![Status](https://img.shields.io/badge/status-experimental-red)](#disclaimer)

> Experimental project. It works, but stability is not guaranteed yet.

</div>

---

## What Is This?

You start a loop. The AI team wakes up, reads shared memory, decides what to do, forms a 3-5 agent task force, executes, updates shared memory, sleeps, and repeats.

```text
launchd/systemd (auto-restart on crash)
  └── auto-loop.sh (continuous loop)
        ├── Read PROMPT.md + consensus.md
        ├── Build dedicated cycle prompt file
        ├── codex exec (run one work cycle from that prompt file)
        │   ├── Read CLAUDE.md (company charter + safety guardrails)
        │   ├── Read .claude/skills/team/SKILL.md (team formation process)
        │   ├── Assemble Agent Team (3-5 people)
        │   ├── Execute: research, coding, deployment, marketing
        │   └── Update memories/consensus.md (cross-cycle relay baton)
        ├── Failure handling: limit wait / circuit breaker / consensus rollback
        └── sleep -> next cycle
```

Each cycle is an independent `codex exec` invocation. `memories/consensus.md` is the only cross-cycle state.

## Team Lineup (14 Agents)

Instead of generic role prompts, agents are modeled after real expert thinking systems.

| Layer | Role | Expert | Core Strength |
|------|------|------|----------|
| Strategy | CEO | Jeff Bezos | PR/FAQ, flywheel, Day 1 mindset |
| | CTO | Werner Vogels | Design for failure, API-first systems |
| | Critical Thinking | Charlie Munger | Inversion, pre-mortem, bias checks |
| Product | Product Design | Don Norman | Affordance, mental models, human-centered design |
| | UI Design | Matias Duarte | Material metaphor, typography-first |
| | Interaction Design | Alan Cooper | Goal-directed design, persona-driven flows |
| Engineering | Full-stack | DHH | Convention over configuration, majestic monolith |
| | QA | James Bach | Exploratory testing, testing != checking |
| | DevOps/SRE | Kelsey Hightower | Serverless-first, automate everything |
| Business | Marketing | Seth Godin | Purple Cow, permission marketing, minimum viable audience |
| | Operations | Paul Graham | Do things that do not scale, ramen profitability |
| | Sales | Aaron Ross | Predictable revenue, funnel optimization |
| | CFO | Patrick Campbell | Value-based pricing, unit economics |
| Intelligence | Research | Ben Thompson | Aggregation theory, value-chain analysis |

Also includes 30+ skills (deep research, web scraping, financial modeling, SEO, security audit, UX audit, etc.), available on demand to any agent.

## Quick Start

```bash
# Prerequisites:
# - macOS or Linux
# - Codex CLI installed and authenticated (`codex login`)
# - OpenAI account with available model quota

git clone https://github.com/nicepkg/auto-company.git
cd auto-company

# Run in foreground (live output)
make start

# Or install as daemon (boot start + crash auto-restart)
make install
```

## Common Commands

```bash
make help        # List all commands
make start       # Start loop in foreground
make start-awake # Start loop + inhibit system sleep
make stop        # Stop loop
make status      # Show status + latest consensus
make monitor     # Live logs
make last        # Last cycle full output
make cycles      # Cycle history summary
make awake       # Inhibit sleep for current loop PID
make install     # Install daemon (launchd on macOS, systemd --user on Linux)
make uninstall   # Uninstall daemon
make pause       # Pause daemon (no auto-restart)
make resume      # Resume daemon
```

## Prevent System Sleep (Recommended)

System sleep pauses work. For long-running loops:

```bash
make start-awake

# If loop is already running:
make awake
```

Notes:
- macOS uses built-in `caffeinate`
- Linux uses `systemd-inhibit` when available
- `make awake` exits automatically when the target PID exits

## Operating Model

### Automatic Convergence (Avoid Endless Discussion)

| Cycle | Action |
|------|------|
| Cycle 1 | Brainstorm: each agent proposes one idea, rank top 3 |
| Cycle 2 | Validate #1: Munger pre-mortem, Thompson market validation, Campbell unit economics -> GO/NO-GO |
| Cycle 3+ | GO -> create repo and ship code; NO-GO -> try next idea. Discussion-only cycles are forbidden |

### Six Standard Workflows

| # | Workflow | Collaboration Chain |
|---|------|--------|
| 1 | New Product Evaluation | Research -> CEO -> Munger -> Product -> CTO -> CFO |
| 2 | Feature Development | Interaction -> UI -> Full-stack -> QA -> DevOps |
| 3 | Product Launch | QA -> DevOps -> Marketing -> Sales -> Operations -> CEO |
| 4 | Pricing & Monetization | Research -> CFO -> Sales -> Munger -> CEO |
| 5 | Weekly Review | Operations -> Sales -> CFO -> QA -> CEO |
| 6 | Opportunity Discovery | Research -> CEO -> Munger -> CFO |

## Steering Direction

The team runs autonomously, but you can intervene anytime:

| Method | Action |
|------|------|
| Change Direction | Edit `memories/consensus.md` -> `Next Action` |
| Pause | `make pause`, then use interactive `codex` |
| Resume | `make resume` |
| Audit Output | Inspect `docs/*/` for each role's artifacts |

## Safety Guardrails

Hard-coded in `CLAUDE.md`, enforced for all agents:

- Do not delete GitHub repositories (`gh repo delete`)
- Do not delete Cloudflare resources (`wrangler delete`)
- Do not delete system files (`~/.ssh/`, `~/.config/`, etc.)
- No illegal activity
- No credential leakage to public repositories
- No force push to `main`/`master`
- All new projects must be created under `projects/`

## Configuration

Override via environment variables:

```bash
MODEL=gpt-5.3-codex make start            # switch model (default: gpt-5.3-codex)
REASONING_EFFORT=high make start          # reasoning effort (default: high)
LOOP_INTERVAL=60 make start                # interval 60s (default: 30)
CYCLE_TIMEOUT_SECONDS=3600 make start      # cycle timeout 1h (default: 1800)
MAX_CONSECUTIVE_ERRORS=3 make start        # circuit breaker threshold (default: 5)
```

## Project Structure

```text
auto-company/
├── CLAUDE.md              # company charter (mission + guardrails + team + workflows)
├── PROMPT.md              # per-cycle execution prompt (convergence rules)
├── Makefile               # command entry points
├── auto-loop.sh           # main loop (watchdog, circuit breaker, log rotation)
├── stop-loop.sh           # stop / pause / resume
├── monitor.sh             # live monitoring
├── install-daemon.sh      # daemon installer (launchd/systemd)
├── memories/
│   └── consensus.md       # cross-cycle relay memory
├── docs/                  # agent outputs (14 role folders)
├── projects/              # workspace for all new projects
├── logs/                  # loop logs
└── .claude/
    ├── agents/            # 14 agent role definitions
    ├── skills/            # 30+ skills (research, finance, marketing, etc.)
    └── settings.json      # local permission defaults for this repo
```

## Dependencies

| Dependency | Description |
|------|------|
| macOS / Linux | daemon management via `launchd` (macOS) or `systemd --user` (Linux) |
| [Codex CLI](https://developers.openai.com/codex/cli) | required and must be authenticated |
| OpenAI account/quota | required for continuous 24/7 usage |
| `jq` | optional, parse JSON cycle logs |
| `gh` | optional, GitHub CLI |
| `wrangler` | optional, Cloudflare CLI |

## Disclaimer

This is an experimental project:

- behavior differs slightly by OS (launchd on macOS, systemd user service on Linux)
- still under test (usable but not guaranteed stable)
- incurs cost (each cycle consumes Codex/OpenAI quota/budget)
- fully autonomous operation (review `CLAUDE.md` safety guardrails carefully)
- no warranty (it may build unexpected things; check `docs/` and `projects/` regularly)

Recommended sequence: run `make start` first, observe behavior, then use `make install`.

## Credits

- [continuous-claude](https://github.com/AnandChowdhary/continuous-claude) - shared memory across sessions
- [ralph-claude-code](https://github.com/frankbria/ralph-claude-code) - exit signal interception
- [claude-auto-resume](https://github.com/terryso/claude-auto-resume) - usage limit recovery
