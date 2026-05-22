# Subagents (子角色 Agent 定义)

每个 `.md` 文件定义一个**专业化角色**,可被主 agent 在需要时分派激活。源自 [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)。

## 入选标准

只保留**与问卷调研 / 数据分析强相关**的角色。其它 600+ 角色(前端/区块链/游戏开发等)留在 hub 不复制。

## 角色清单与适用场景

| 角色 | 何时调用 |
|---|---|
| **data-scientist** | 端到端建模任务:从 EDA 到回归/分类/聚类到评估 |
| **data-analyst** | 业务向分析、看板、KPI 拆解 |
| **data-engineer** | 数据清洗、ETL、字段映射、变量字典 |
| **data-researcher** | 数据驱动的问题发现与假设生成 |
| **ml-engineer** | 模型部署、API 封装、A/B 测试 |
| **nlp-engineer** | 开放题文本处理:分词、词云、情感、主题 |
| **prompt-engineer** | 优化系统提示、设计工具描述、评估 prompt |
| **research-analyst** | 行业基线、竞品对标、报告框架 |
| **scientific-literature-researcher** | 学术文献检索、综述、引用 |

## 调用约定(规划中)

在 `app/agent.py` 中扩展(对应 issue #1 的 fe-ux-overhaul 后续):

```python
# 伪代码
def dispatch_subagent(role: str, task: str) -> str:
    role_prompt = (BASE_DIR / "agent" / "subagents" / f"{role}.md").read_text()
    return run_subagent(system_prompt=role_prompt, user_task=task)
```

主 agent 通过工具 `dispatch_subagent(role, task)` 调用,子 agent 独立上下文跑完后返回摘要。

## 与 skills 的区别

- **Skill**: 一个**做事方法论**(SOP),被注入到 agent 的上下文里
- **Subagent**: 一个**独立的小 agent**,有自己的系统提示和上下文窗口

通常 subagent 会同时**引用多个 skills** 来完成任务。
