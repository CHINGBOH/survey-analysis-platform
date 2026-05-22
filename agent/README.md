# Agent 资源目录

本目录承载驱动 Survey Analysis Platform 的 LLM Agent 全部资源:系统提示、技能(skills)、子角色(subagents)与架构设计参考。所有 skills/subagents 均改编自本地 [agent-infra-hub](/home/l/projects/agent-infra-hub),并按本项目领域(SPSS 风格问卷分析)收敛。

## 目录结构

```
agent/
├── README.md                 ← 本文件
├── system_prompt.md          ← 主系统提示 (app/agent.py 加载)
├── skills/                   ← 技能(SKILL.md + 支持脚本)
│   ├── r-quarto/             ← R / Quarto 工程规范
│   ├── data-analysis/        ← EDA / 回归 / 聚类 / 文本
│   ├── research/             ← 学术报告写作与研究流水线
│   └── workflow/             ← 流程门禁(plan/design review、PR 管理)
├── subagents/                ← 角色化子 agent 定义
└── design/                   ← Agent 架构设计参考与外链
```

## 技能(Skills)

每个 skill 是一个独立目录,根部含 `SKILL.md`(YAML frontmatter + 正文)。Frontmatter 至少包含:

```yaml
---
name: <kebab-case-name>
description: <一句话描述用途与适用场景>
---
```

下游 runtime(Claude Code / Copilot CLI / 自研 Agent)只需扫描 `**/SKILL.md` 即可发现并按需注入到上下文。

### R / Quarto(`agent/skills/r-quarto/`)

| Skill | 用途 |
|---|---|
| `writing-r-code` | R 代码风格、tidyverse 习惯、错误处理 |
| `writing-qmd-scientific` | 科学 Quarto 文档(含交叉引用、引文、图编号) |
| `creating-analysis-projects` | 标准分析项目结构(`R/`、`output/`、`renv` 等) |
| `developing-r-packages` | R 包开发流程 |
| `r-package-development` | r-lib 风格的包结构 |
| `testing-r-packages` | testthat 测试模式 |
| `quarto-authoring` | Quarto 章节、参数化、扩展 |
| `ggsql` | SQL + ggplot2 联用 |
| `brand-yml` | Posit `_brand.yml` 主题(对 chart 模块直接可用) |

### 数据分析(`agent/skills/data-analysis/`)

| Skill | 用途 |
|---|---|
| `data-exploration-visualization` | 自动 EDA + 多类图表 + 报告生成 |
| `regression-analysis-modeling` | 线性 / Logistic / 诊断 / 预测 |
| `ab-testing-analyzer` | t 检验 / 卡方 / 效应量 / 功效 |
| `rfm-customer-segmentation` | K-means / 层次 / 两步聚类 |
| `retention-analysis` | 队列 / 留存 / 生存分析 |
| `content-analysis` | 文本分析(开放题、情感、主题) |

### 研究(`agent/skills/research/`)

| Skill | 用途 |
|---|---|
| `academic-paper` | 学术论文写作流水线 |
| `academic-paper-reviewer` | 论文同行评审清单 |
| `academic-pipeline` | 数据 → 分析 → 论文全流程 |
| `deep-research` | 深度调研(用于做行业基线、文献综述) |

### 工作流(`agent/skills/workflow/`)

| Skill | 用途 |
|---|---|
| `plan-review-gate` | 规划评审门禁(强制 plan→review→execute) |
| `design-review-gate` | 设计评审门禁 |
| `orchestrated-execution` | 多步任务编排 |
| `handling-pr-comments` | 系统化处理 PR 评论 |
| `create-issue` | 规范化创建 issue |
| `pr-shepherd` | PR 全生命周期看护 |
| `brainstorming-extension` | 头脑风暴扩展 |

## 子 Agent(`agent/subagents/`)

来自 [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents),保留与本项目领域强相关的角色:

| 子 Agent | 主战场 |
|---|---|
| `data-scientist.md` | 端到端建模(EDA→模型→评估) |
| `data-analyst.md` | 业务分析、报表、看板 |
| `data-engineer.md` | 数据管道、ETL、清洗 |
| `data-researcher.md` | 数据驱动的调研与发现 |
| `ml-engineer.md` | 模型工程化、部署 |
| `nlp-engineer.md` | 文本/分词/主题/情感 |
| `prompt-engineer.md` | 提示工程、评估 |
| `research-analyst.md` | 业务/市场/行业研究 |
| `scientific-literature-researcher.md` | 学术文献调研(可与 deep-research skill 联用) |

## 设计参考(`agent/design/`)

见 `design/README.md`。索引外部资料(metaswarm、agent-orchestrator、ultimate-guide 等)而非全文复制,避免仓库膨胀。

## Runtime 接入说明

### 当前(`app/agent.py`)
目前主 agent 直接加载 `system_prompt.md`,**未自动扫描** `skills/`。需要时由开发者从 skill 文档摘录关键段落注入 prompt。

### 规划(对应 issue #1)
- [ ] `app/agent.py` 启动时扫描 `agent/skills/**/SKILL.md`,按 phase / 工具调用动态注入 skill 上下文。
- [ ] `app/router.py` 引入 subagent 概念,在复杂任务下分派角色。
- [ ] `agent/skills/workflow/plan-review-gate` 接入 `set_analysis_plan` 工具流程。

## 与 agent-infra-hub 的同步策略

本仓库内的 skills 是**快照副本**(不是 symlink),便于:
1. 项目独立演进、按本领域定制
2. 离线/打包分发
3. Git 历史可追溯

如需从上游 hub 同步更新,人工 diff 或使用 `tools/sync-from-hub.sh`(待编写)。

## 来源致谢

- [posit-dev-skills](https://github.com/posit-dev/skills) — R/Quarto/Shiny/Connect
- [agentic-skills](https://github.com/jhrcook/agentic-skills) — 科研写作流水线
- [claude-data-analysis-ultra](https://github.com/datawhalechina) — 数据分析专家级技能
- [academic-research-skills](https://github.com/zhulingjie/academic-research-skills) — 学术研究
- [metaswarm](https://github.com/anthropics/metaswarm) — 多 agent 工作流
- [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — subagent 集
