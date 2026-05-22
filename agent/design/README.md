# Agent 架构设计参考

本目录不堆放代码,而是索引**外部参考资料**,避免仓库膨胀同时保留学习路径。

## 当前 Agent 架构(本仓库 `app/`)

```
用户消息
   ↓
[app/router.py] determine_phase()  —— 根据文件系统状态推导当前 phase
   ↓
[app/hooks.py]  pre_tool_use()     —— 硬性 gate 检查(prerequisite)
   ↓
[app/agent.py]  ReAct loop         —— DeepSeek v4-pro + tool calling
   ↓
[app/tools.py]  11 个工具          —— R/Python subprocess
   ↓
[app/state.py]  state 持久化       —— streamlit session_state + 文件系统
```

### 关键设计原则
- **路由是软的、Hook 是硬的**: router 收窄工具暴露(UX),hooks 强制依赖检查(正确性)。
- **Phase 推导基于文件系统**: 不读 LLM 自报,只看 `output/results/*.rds` 等是否存在。
- **set_analysis_plan 是反幻觉门**: 任何分析动作前必须先调它,plan 落地 `plan.json`,所有后续工具读它。
- **HTTPS 旁路代理**: `_make_client()` 用 `httpx.HTTPTransport()` 绕过 `ALL_PROXY` / `HTTPS_PROXY`。

## 外部参考(全部本地缓存,见 `/home/l/projects/agent-infra-hub/`)

### Agent 设计模式
| 来源 | 路径 | 看点 |
|---|---|---|
| **metaswarm** | `07-agent-design/metaswarm/` | 工作流门禁 + 多 agent 编排 |
| **agent-orchestrator** | `07-agent-design/agent-orchestrator/` | 编排模式参考 |
| **claude-swarm** | `07-agent-design/claude-swarm/` | swarm 模式 |
| **ccswarm** | `07-agent-design/ccswarm/` | 轻量 swarm |
| **agent-farm** | `07-agent-design/agent-farm/` | agent 池 |
| **wshobson-agents** | `07-agent-design/wshobson-agents/` | 实战 agent 库 |
| **ruflo** | `07-agent-design/ruflo/` | 流程引擎 |
| **Dive-into-Claude-Code** | `07-agent-design/Dive-into-Claude-Code/` | CC 内核解析 |
| **ultimate-guide** | `07-agent-design/ultimate-guide/` | 综合指南 |

### Subagent 灵感库
- `05-subagents/awesome-claude-code-subagents/categories/` — 全 10 类 subagent
- 本仓库 `agent/subagents/` 已选录 9 个与数据分析强相关的

### 上游 SKILL 标准
所有 SKILL.md 遵循 frontmatter 协议:
```yaml
---
name: kebab-case-name
description: 一句话,被 LLM 用作分流依据
allowed-tools: Read, Write, Bash  # 可选
---
```

详见 Anthropic 官方 [Claude Skills 文档](https://docs.claude.com/en/docs/claude-code/skills)。

## 演进方向(对应 issue #1)

1. **plan-review-gate 内嵌**: `app/tools.py:set_analysis_plan` 增加确认环节,引用 `agent/skills/workflow/plan-review-gate/SKILL.md` 描述的双重确认协议。
2. **Skill 动态注入**: `app/agent.py` 启动时扫 `agent/skills/**/SKILL.md`,把 description 拼成系统提示的 "可用技能" 段落;工具调用涉及某 skill 时再读全文。
3. **Subagent 分派**: 复杂请求(如"做一份完整的市场调研报告")自动启动 `research-analyst` + `data-scientist` + `nlp-engineer` 三角色并行。
4. **可观测性**: 接入 langfuse / phoenix 跟踪 ReAct 循环每一步(见 `docs/agent-framework-research.md`)。
