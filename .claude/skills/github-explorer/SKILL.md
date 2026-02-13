---
name: github-explorer
description: >
  Deep-dive analysis of GitHub projects. Use when the user mentions a GitHub repo/project name
  and wants to understand it - triggered by phrases like "review this project", "analyze this repo",
  "is this project good", or any request to explore/evaluate a GitHub project.
  Covers architecture, community health, competitive landscape, and cross-platform knowledge sources.
---

# GitHub Explorer - Deep Project Analysis

> **Philosophy**: README is the storefront. Real value is often hidden in Issues, Commits, and community discussions.

## Workflow

```text
[project name] -> [1. locate repo] -> [2. multi-source collection] -> [3. analysis] -> [4. structured output]
```

### Phase 1: Locate Repo

- Use `web_search` with `site:github.com <project_name>` to confirm `org/repo`
- Use `search-layer` (Deep mode + intent-aware scoring) to collect community links and non-GitHub references:
  ```bash
  python3 skills/search-layer/scripts/search.py \
    --queries "<project_name> review" "<project_name> user experience" \
    --mode deep --intent exploratory --num 5
  ```
- Use `web_fetch` on repo homepage for base metadata (README, stars, forks, license, latest update)

### Phase 2: Multi-Source Collection (Parallel)

Check sources on demand. If a source is missing, skip it.

| Source | URL Pattern | What To Collect | Suggested Tool |
|---|---|---|---|
| GitHub Repo | `github.com/{org}/{repo}` | README, About, Contributors | `web_fetch` |
| GitHub Issues | `github.com/{org}/{repo}/issues?q=sort:comments` | Top 3-5 high-signal issues | `browser` |
| Regional/Language Communities | Reddit, Hacker News, forums, blogs | practical reviews, user experience reports | `search-layer` / `content-extract` |
| Technical Blogs | Medium/Dev.to/personal blogs | architecture deep dives | `web_fetch` / `content-extract` |
| Discussion Boards | V2EX/Reddit/HN/etc. | pain points, adoption friction, sentiment | `search-layer` (Deep mode) |

#### search-layer Usage

search-layer v2 supports intent-aware scoring. Recommended invocations:

| Scenario | Command | Notes |
|------|------|------|
| **default project research** | `python3 skills/search-layer/scripts/search.py --queries "<project> review" "<project> use cases" --mode deep --intent exploratory --num 5` | parallel multi-query, authority-aware ranking |
| **latest updates** | `python3 skills/search-layer/scripts/search.py "<project> latest release" --mode deep --intent status --freshness pw --num 5` | freshness-prioritized (past week) |
| **competitor comparison** | `python3 skills/search-layer/scripts/search.py --queries "<project> vs <competitor>" "<project> alternatives" --mode deep --intent comparison --num 5` | comparison intent scoring |
| **fast link lookup** | `python3 skills/search-layer/scripts/search.py "<project> official docs" --mode fast --intent resource --num 3` | precision lookup |
| **community discussion** | `python3 skills/search-layer/scripts/search.py "<project> discussion experience" --mode deep --intent exploratory --domain-boost reddit.com,news.ycombinator.com --num 5` | weighted community sites |

Intent quick reference: `factual`, `status`, `comparison`, `tutorial`, `exploratory`, `news`, `resource`.

If `--intent` is omitted, behavior is backward-compatible with v1 (raw order, no intent scoring).

Fallback policy:
- If Exa/Tavily returns 429/5xx, continue with remaining providers
- If search-layer fails entirely, fall back to single-source `web_search`

---

### Extraction Upgrade Protocol

When any of the following happens, **upgrade from `web_fetch` to `content-extract`**:

1. **Known hard domains**: heavily protected/community pages with poor `web_fetch` extraction quality.
2. **Complex structure**: heavy LaTeX, complex tables, or badly structured markdown output.
3. **Content loss**: anti-bot challenge page or near-empty content from `web_fetch`.

Invocation:

```bash
python3 skills/content-extract/scripts/content_extract.py --url <URL>
```

`content-extract` behavior:
- domain-based extractor routing when needed
- probe via `web_fetch` first, then fallback extractor path
- returns unified JSON contract (`ok`, `markdown`, `sources`, etc.)

### Phase 3: Analysis

Use collected data to classify and judge:

- **Project stage**: early experiment / fast growth / mature stable / maintenance mode / stagnating (based on commit frequency + quality)
- **Issue selection standard**: high comment volume, maintainer involvement, architecture signal, high-quality technical discussion
- **Competitor identification**: from README comparison sections, issue discussions, and search results

### Phase 4: Structured Output

Use this template strictly. Every module must contain substance or explicitly say "not found".

#### Formatting Rules (Required)

1. **Title must be clickable and point to GitHub repo**: `# [Project Name](https://github.com/org/repo)`
2. Keep clear spacing between sections
3. **Competitor section must include links** (GitHub/site/docs)
4. **Community signals must be concrete**: summarize specific posts/comments with links, not vague claims like "high traction"
5. **Traceability**: every external claim should include source URL

```markdown
# [{Project Name}]({GitHub Repo URL})

**One-line Positioning**

{What it is and what problem it solves}

**Core Mechanism**

{Explain architecture/technical model in plain language, including key stack}

**Project Health**

- **Stars**: {count}  |  **Forks**: {count}  |  **License**: {type}
- **Team/Author**: {background}
- **Commit Trend**: {recent activity + stage judgment}
- **Recent Changes**: {key recent commit summary}

**Selected Issues**

{Top 3-5 issues with title, link, and discussion signal. If none, explicitly state that.}

**Best-fit Use Cases**

{When to use it and what concrete problem it solves}

**Limitations**

{Known constraints and when not to use it}

**Competitor Comparison**

- **vs [Competitor A](https://...)** - difference summary
- **vs [Competitor B](https://...)** - difference summary

**Knowledge Graph Presence**

- **DeepWiki**: {link or "not found"}
- **Zread.ai**: {link or "not found"}

**Demo**

{live demo URL or "none"}

**Related Papers**

{arXiv link(s) or "none"}

**Community Signal**

**X/Twitter**

- [source link]: summary of what was said
- [source link]: specific concern/use case discussed

**Other Communities**

- [source link]: post summary
- [source link]: discussion summary

**Assessment**

{Your judgment: is it worth time investment, for which user level, and suggested adoption path}
```

## Execution Notes

- Prefer `web_search` + `web_fetch`; use browser rendering when needed
- For project research, default to `search-layer` v2 deep mode with `--intent exploratory`
- If `web_fetch` fails/403/challenge page/too-short content, force upgrade to `content-extract`
- Collect sources in parallel
- All links must be real and reachable; never fabricate URLs
- Output in clear English with technical terms preserved

## Output Checklist (Required)

Before sending, verify every item:

- [ ] Title uses clickable repo format `# [Project Name](GitHub URL)`
- [ ] Every required section is present
- [ ] Selected Issues include complete links
- [ ] Every competitor includes at least one valid link
- [ ] Community signal entries include direct source links
- [ ] No vague claim-only statements (must include concrete evidence)
- [ ] Every external claim has a traceable source URL

## Dependencies

This skill depends on these tools/skills:

| Dependency | Type | Purpose |
|------|------|------|
| `web_search` | built-in tool | discovery and retrieval |
| `web_fetch` | built-in tool | page content fetching |
| `browser` | built-in tool | dynamic rendering fallback |
| `search-layer` | skill | multi-source search + intent-aware ranking |
| `content-extract` | skill | high-fidelity extraction for protected/complex pages |
