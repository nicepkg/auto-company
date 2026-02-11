<div align="center">

# Auto Company

**全自主 AI 公司，24/7 不停歇运行**

14 个 AI Agent，每个都是该领域世界顶级专家的思维分身。
自主构思产品、做决策、写代码、部署上线、搞营销。没有人类参与。

基于 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) Agent Teams 驱动。

[![macOS](https://img.shields.io/badge/平台-macOS-blue)](#依赖)
[![Claude Code](https://img.shields.io/badge/驱动-Claude%20Code-orange)](https://docs.anthropic.com/en/docs/claude-code)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](#license)
[![Status](https://img.shields.io/badge/状态-实验中-red)](#%EF%B8%8F-免责声明)

> **⚠️ 实验项目** — 还在测试中，能跑但不一定稳定。目前仅支持 macOS。

</div>

---

## 这是什么？

你启动一个循环。AI 团队醒来，读取共识记忆，决定干什么，组建 3-5 人小队，执行任务，更新共识记忆，然后睡一觉。接着又醒来。如此往复，永不停歇。

```
launchd (崩溃自重启)
  └── auto-loop.sh (永续循环)
        ├── 读 PROMPT.md + consensus.md
        ├── claude -p (驱动一个工作周期)
        │   ├── 读 CLAUDE.md (公司章程 + 安全红线)
        │   ├── 读 .claude/skills/team/SKILL.md (组队方法)
        │   ├── 组建 Agent Team (3-5 人)
        │   ├── 执行：调研、写码、部署、营销
        │   └── 更新 memories/consensus.md (传递接力棒)
        ├── 失败处理: 限额等待 / 熔断保护 / consensus 回滚
        └── sleep → 下一轮
```

每个周期是一次独立的 `claude -p` 调用。`memories/consensus.md` 是唯一的跨周期状态——类似接力赛传棒。

## 团队阵容（14 人）

不是"你是一个开发者"，而是"你是 DHH"——用真实传奇人物激活 LLM 的深层知识。

| 层级 | 角色 | 专家 | 核心能力 |
|------|------|------|----------|
| **战略** | CEO | Jeff Bezos | PR/FAQ、飞轮效应、Day 1 心态 |
| | CTO | Werner Vogels | 为失败而设计、API First |
| | 逆向思考 | Charlie Munger | 逆向思维、Pre-Mortem、心理误判清单 |
| **产品** | 产品设计 | Don Norman | 可供性、心智模型、以人为本 |
| | UI 设计 | Matías Duarte | Material 隐喻、Typography 优先 |
| | 交互设计 | Alan Cooper | Goal-Directed Design、Persona 驱动 |
| **工程** | 全栈开发 | DHH | 约定优于配置、Majestic Monolith |
| | QA | James Bach | 探索性测试、Testing ≠ Checking |
| | DevOps/SRE | Kelsey Hightower | Serverless 优先、自动化一切 |
| **商业** | 营销 | Seth Godin | 紫牛、许可营销、最小可行受众 |
| | 运营 | Paul Graham | Do Things That Don't Scale、拉面盈利 |
| | 销售 | Aaron Ross | 可预测收入、漏斗思维 |
| | CFO | Patrick Campbell | 基于价值定价、单位经济学 |
| **情报** | 调研分析 | Ben Thompson | Aggregation Theory、价值链分析 |

另配 **30+ 技能**（深度调研、网页抓取、财务建模、SEO、安全审计、UX 审计……），任何 Agent 按需取用。

## 快速开始

```bash
# 前提:
# - macOS
# - 已安装 Claude Code CLI 并登录
# - Claude Max / Pro 订阅（或 API 额度）

# 克隆
git clone https://github.com/nicepkg/auto-company.git
cd auto-company

# 前台运行（直接看输出）
make start

# 或安装为守护进程（开机自启 + 崩溃自重启）
make install
```

## 常用命令

```bash
make help       # 查看所有命令
make start      # 前台启动循环
make stop       # 停止循环
make status     # 查看状态 + 最新共识
make monitor    # 实时日志
make last       # 上一轮完整输出
make cycles     # 历史周期摘要
make install    # 安装 launchd 守护进程
make uninstall  # 卸载守护进程
make pause      # 暂停（不自动拉起）
make resume     # 恢复
```

## 运作机制

### 自动收敛（防止无限讨论）

| 周期 | 动作 |
|------|------|
| Cycle 1 | 头脑风暴——每个 Agent 提一个想法，排出 top 3 |
| Cycle 2 | 验证 #1——Munger 做 Pre-Mortem，Thompson 验证市场，Campbell 算账 → **GO / NO-GO** |
| Cycle 3+ | GO → 建 repo 写代码部署。NO-GO → 试下一个。**纯讨论禁止** |

### 六大标准流程

| # | 流程 | 协作链 |
|---|------|--------|
| 1 | **新产品评估** | 调研 → CEO → Munger → 产品 → CTO → CFO |
| 2 | **功能开发** | 交互 → UI → 全栈 → QA → DevOps |
| 3 | **产品发布** | QA → DevOps → 营销 → 销售 → 运营 → CEO |
| 4 | **定价变现** | 调研 → CFO → 销售 → Munger → CEO |
| 5 | **每周复盘** | 运营 → 销售 → CFO → QA → CEO |
| 6 | **机会发现** | 调研 → CEO → Munger → CFO |

## 引导方向

AI 团队全自主运行，但你可以随时介入：

| 方式 | 操作 |
|------|------|
| **改方向** | 修改 `memories/consensus.md` 的 "Next Action" |
| **暂停** | `make pause`，然后 `claude` 交互式沟通 |
| **恢复** | `make resume`，回到自主模式 |
| **审查产出** | 查看 `docs/*/`——每个 Agent 的工作成果 |

## 安全红线

写死在 `CLAUDE.md`，对所有 Agent 强制生效：

- 不得删除 GitHub 仓库（`gh repo delete`）
- 不得删除 Cloudflare 项目（`wrangler delete`）
- 不得删除系统文件（`~/.ssh/`、`~/.config/` 等）
- 不得进行非法活动
- 不得泄露凭证到公开仓库
- 不得 force push 到 main/master
- 所有新项目必须在 `projects/` 目录下创建

## 配置

环境变量覆盖：

```bash
MODEL=sonnet make start                    # 换模型（默认 opus）
LOOP_INTERVAL=60 make start                # 60 秒间隔（默认 30）
CYCLE_TIMEOUT_SECONDS=3600 make start      # 单轮超时 1 小时（默认 1800）
MAX_CONSECUTIVE_ERRORS=3 make start        # 熔断阈值（默认 5）
```

## 项目结构

```
auto-company/
├── CLAUDE.md              # 公司章程（使命 + 安全红线 + 团队 + 流程）
├── PROMPT.md              # 每轮工作指令（收敛规则）
├── Makefile               # 常用命令
├── auto-loop.sh           # 主循环（watchdog、熔断器、日志轮转）
├── stop-loop.sh           # 停止 / 暂停 / 恢复
├── monitor.sh             # 实时监控
├── install-daemon.sh      # launchd 守护进程安装器
├── memories/
│   └── consensus.md       # 共识记忆（跨周期接力棒）
├── docs/                  # Agent 产出（14 个目录）
├── projects/              # 所有新建项目的工作空间
├── logs/                  # 循环日志
└── .claude/
    ├── agents/            # 14 个 Agent 定义（专家人格）
    ├── skills/            # 30+ 技能（调研、财务、营销……）
    └── settings.json      # 权限 + Agent Teams 开关
```

## 依赖

| 依赖 | 说明 |
|------|------|
| **macOS** | 使用 `launchd` 管理守护进程，Linux (systemd) 后续支持 |
| **[Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)** | 必须安装并登录 |
| **Claude 订阅** | 推荐 Max 或 Pro，24/7 运行需要持续额度 |
| `jq` | 可选，解析 JSON 周期日志 |
| `gh` | 可选，GitHub CLI |
| `wrangler` | 可选，Cloudflare CLI |

## ⚠️ 免责声明

这是一个**实验项目**：

- **仅支持 macOS** — Linux/systemd 尚未实现
- **还在测试中** — 能跑，但不保证稳定
- **会花钱** — 每个周期消耗 Claude API 额度或订阅配额
- **完全自主** — AI 团队自己做决策，不会问你。请认真设置 `CLAUDE.md` 中的安全红线
- **无担保** — AI 可能会构建你意想不到的东西，定期检查 `docs/` 和 `projects/`

建议先用 `make start`（前台）观察行为，确认没问题再 `make install`（守护进程）。

## 致谢

- [continuous-claude](https://github.com/AnandChowdhary/continuous-claude) — 跨会话共享笔记
- [ralph-claude-code](https://github.com/frankbria/ralph-claude-code) — 退出信号拦截
- [claude-auto-resume](https://github.com/terryso/claude-auto-resume) — 用量限制恢复

## License

MIT
