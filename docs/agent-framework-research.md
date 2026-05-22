
# 数据分析 Agent 框架增强调研

> **版本**: 2025-05-22 | **调研者**: Research Subagent  
> **基于现有代码**: `app/agent.py`（手写 ReAct 循环）、`app/router.py`（Hub-and-Spoke Phase 路由）、`app/hooks.py`（预/后工具钩子）、`app/tools.py`（11 个 R/Python 工具）、`app/state.py`（Pipeline 状态机）

---

## 总览与建议优先级

| 优先级 | 库/工具 | 一句话理由 |
|--------|---------|-----------|
| **P0** | **Langfuse** | 零侵入 OpenTelemetry 可观测性，立刻看到 ReAct 每轮 token 成本和工具成功率 |
| **P0** | **instructor** | 用 Pydantic 模型直接约束 LLM 结构化输出，消灭幻觉 JSON；已与 DeepSeek OpenAI 兼容 API 无缝对接 |
| **P0** | **pyreadstat** | 直接读 .sav/.por 文件，避免 SPSS 数据转 Excel 的信息丢失 |
| **P1** | **LangGraph** | 把现有手写 ReAct loop 升级为状态图，获得持久化、断点续跑、Human-in-loop |
| **P1** | **Pydantic AI** | FastAPI 风格 Agent SDK，类型安全、DeepSeek 原生支持、内置 Logfire 可观测 |
| **P1** | **LIDA (Microsoft)** | 将可视化生成升级为 LLM 驱动的 Goal→Chart 管道，可 wrap 成 tool |
| **P1** | **LanceDB** | 轻量嵌入式向量库，用于问卷变量字典、调研文档的 RAG 检索 |
| **P1** | **fg-data-profiling** | 一键 EDA 报告，结构化快速探索数据质量，可作 preview_data 增强工具 |
| **P2** | **DSPy** | 声明式 Prompt 编程，把 system_prompt.md 变成可 A/B 测试、自动优化的程序 |
| **P2** | **E2B** | 云端隔离沙箱替代 subprocess，让 LLM 写的 R/Python 在安全环境执行 |

---

## 1. Agent 编排框架

### 1.1 LangGraph ⭐ **强烈推荐 P1**

| 指标 | 数据 |
|------|------|
| GitHub | [langchain-ai/langgraph](https://github.com/langchain-ai/langgraph) |
| Stars (2025-05) | **32,691** ⭐ |
| 最新版本 | v0.4.x（2025 年持续迭代） |
| 许可证 | MIT |

**简介**  
LangGraph 是 LangChain 团队推出的**低层级状态图编排框架**，将 Agent 的推理流程建模为有向图（节点 = Python 函数，边 = 条件路由）。其核心特性：持久化执行（可从失败处恢复）、Human-in-the-loop（可在任意节点暂停等待用户确认）、丰富的内存管理。

**与本项目的对应关系**  
当前 `app/agent.py` 是一个 `for _round in range(MAX_TOOL_ROUNDS)` 手写循环，`app/router.py` 用 `determine_phase()` 做 phase 路由，`app/hooks.py` 用 `pre_tool_use`/`post_tool_use` 做生命周期钩子。LangGraph 能原生表达这一切：

```python
# 现有手写循环 → LangGraph 状态图等价
from langgraph.graph import StateGraph, END
from typing import TypedDict

class AgentState(TypedDict):
    messages: list
    phase: str          # 对应 app/state.py Phase
    plan: dict          # 对应 AnalysisPlan
    tool_rounds: int

graph = StateGraph(AgentState)
graph.add_node("router",   route_node)      # 对应 app/router.py
graph.add_node("llm_call", llm_node)        # 对应 agent.py 中的 API 调用
graph.add_node("tool_exec", tool_node)      # 对应 _dispatch()
graph.add_node("hook_gate", hook_gate_node) # 对应 app/hooks.py pre_tool_use

graph.add_conditional_edges("llm_call", decide_next, {
    "tool": "hook_gate",
    "end":  END,
})
```

**集成路径（具体改动文件）**  
1. `app/agent.py` → 重写 `run_agent_turn()` 为 LangGraph 编译图，保留现有 `_dispatch()` 和 `_make_client()`
2. `app/router.py` → `route()` 成为 LangGraph 的条件边函数，逻辑不变
3. `app/hooks.py` → `pre_tool_use` 变成 `hook_gate` 节点，`post_tool_use` 变成工具节点的后处理
4. `app/state.py` → `AppState` dataclass 扩展为 `TypedDict` 以符合 LangGraph 要求

**增益**：获得内置 checkpointing（SQLite/Redis），断线重连；Human-in-loop 可在 `set_analysis_plan` 前暂停等用户确认；LangSmith 一键 trace。

**缺点 / 取舍**  
- 学习曲线：状态图思维与直觉的循环不同，需要约 1-2 天上手
- 依赖 LangChain 生态（虽然可独立使用），增加依赖体积
- DeepSeek v4-pro 的 `reasoning_content` 需要自定义处理（LangChain 原生可能不传递该字段）
- **迁移成本约 2-3 天**；考虑到现有代码结构清晰，属于**值得做的渐进升级**

---

### 1.2 Pydantic AI ⭐ **强烈推荐 P1**

| 指标 | 数据 |
|------|------|
| GitHub | [pydantic/pydantic-ai](https://github.com/pydantic/pydantic-ai) |
| Stars (2025-05) | **17,212** ⭐（2024 年 11 月发布，增长极快） |
| 最新版本 | v0.2.x（2025 年活跃开发） |
| 许可证 | MIT |

**简介**  
Pydantic 团队打造的"FastAPI 风格" Agent 框架。核心价值：**完全类型安全的工具定义**（IDE 补全 + mypy 检查）、原生支持 DeepSeek、内置 Pydantic Logfire 可观测性。

**与本项目的契合点**  
当前 `app/tools.py` 已经用 Pydantic 的 `AnalysisPlan` 做参数校验，Pydantic AI 可以将全部 11 个工具升级为类型安全的声明式定义：

```python
from pydantic_ai import Agent
from pydantic_ai.models.openai import OpenAIModel  # 兼容 DeepSeek

model = OpenAIModel(
    "deepseek-v4-pro",
    base_url="https://api.deepseek.com",
    api_key=os.environ["DEEPSEEK_API_KEY"]
)

agent = Agent(model, system_prompt=load_system_prompt())

@agent.tool
async def run_analysis_module(ctx, module: Literal["descriptives", "regression", ...]) -> AnalysisResult:
    """运行单个统计分析模块（Rscript）"""
    return await _run_r_module(module)
```

**集成路径**  
1. 创建 `app/agent_pydantic.py`，将 `TOOL_DEFS` JSON schema 改为 Python 函数装饰器
2. `app/hooks.py` 的 `pre_tool_use` → 用 Pydantic AI 的 `RunContext` 实现
3 .`app/main.py` 的 Streamlit 层无需改动

**缺点 / 取舍**  
- 框架较新（v0.2），API 仍在演进，生产稳定性待观察
- 不支持 LangGraph 那样的持久化图状态
- DeepSeek `reasoning_content` 字段需要自定义 model 包装器处理

---

### 1.3 Microsoft AutoGen（进入维护模式）→ 改为 Microsoft Agent Framework

| 指标 | AutoGen | Microsoft Agent Framework (MAF) |
|------|---------|----------------------------------|
| GitHub | [microsoft/autogen](https://github.com/microsoft/autogen) | [microsoft/agent-framework](https://github.com/microsoft/agent-framework) |
| Stars | **58,288** ⭐（历史积累） | 新仓库，增长中 |
| 状态 | ⚠️ **维护模式，不推荐新项目** | ✅ 生产可用，1.0 发布 |

**评估**：AutoGen 已宣布进入维护模式，官方推荐迁移到 Microsoft Agent Framework（MAF）。MAF 支持图形化编排、A2A 协议、MCP 工具、持久化 workflow，Python + .NET 双语言。对于纯 Python 数据分析项目，MAF 的优势不如 LangGraph 直观，**不建议迁移**。

---

### 1.4 CrewAI

| 指标 | 数据 |
|------|------|
| GitHub | [crewAIInc/crewAI](https://github.com/crewAIInc/crewAI) |
| Stars (2025-05) | **51,954** ⭐ |
| 最新版本 | v0.102.0（2025 年活跃） |
| 许可证 | MIT |

**简介**：面向"角色扮演多 Agent"的高层框架。一个 Crew = 多个具有 role/goal/backstory 的 Agent + Tasks + Tools。独立于 LangChain，完全从头构建。

**与本项目契合度：中等**  
本项目是单 Agent + 工具调用模式，CrewAI 的优势在于多角色协作。但若未来引入"数据清洗专家 + 统计学家 + 报告撰写员"的分工，CrewAI 的 `Flow`（事件驱动流程）比较适合。当前阶段**不建议迁移**，可在 Phase 2 考虑作为多 Agent 扩展方案。

---

### 1.5 OpenAI Agents SDK

| 指标 | 数据 |
|------|------|
| GitHub | [openai/openai-agents-python](https://github.com/openai/openai-agents-python) |
| Stars | ~15,000 ⭐（估算，新仓库） |

**评估**：虽然标榜 provider-agnostic，但与 OpenAI 生态深度绑定（Responses API、hosted tools）。DeepSeek 兼容性需要手写 adapter。对于已使用 DeepSeek 的本项目，不推荐作为主框架。

---

### 1.6 DSPy ⭐ **推荐 P2**

| 指标 | 数据 |
|------|------|
| GitHub | [stanfordnlp/dspy](https://github.com/stanfordnlp/dspy) |
| Stars (2025-05) | **34,584** ⭐ |
| 最新版本 | v2.6.x（2025 年活跃） |
| 许可证 | MIT |

**简介**：斯坦福出品，"编程 LM 而非提示 LM"。核心思想：把 Prompt 写成带输入/输出签名的 Module，然后用 `BootstrapFewShot`、`MIPROv2` 等优化器自动调优。

**与本项目的集成路径**：  
当前 `agent/system_prompt.md` 是硬编码的中文 Markdown。用 DSPy 可以：

```python
import dspy

class AnalysisPlanExtractor(dspy.Signature):
    """从用户自然语言中提取结构化分析计划"""
    user_request: str = dspy.InputField()
    surveys: list[str] = dspy.OutputField(desc="调查编号列表")
    modules: list[str] = dspy.OutputField(desc="统计模块列表")
    focus: str = dspy.OutputField(desc="核心研究问题")

extractor = dspy.ChainOfThought(AnalysisPlanExtractor)
```

通过离线评估数据集自动优化 prompt，减少 `set_analysis_plan` 的幻觉错误。

**缺点**：DSPy 的优化器需要评估数据集，冷启动成本较高；对实时流式输出（Generator）支持有限；**建议 P2 阶段再引入**。

---

### 编排框架总评估

**最适合从手写 ReAct Loop 升级的方案**：

```
最小侵入（立刻做）:   instructor + Langfuse（不改架构）
中期重构（1-2月）:   LangGraph（保留现有 router/hooks 逻辑，获得持久化）
或者:               Pydantic AI（全面类型安全重写，更简洁）
长期（可选）:        DSPy 优化 prompts + CrewAI 多角色扩展
```

**是否值得迁移**：现有代码架构质量较高（清晰的 Phase/Hook 分层），**不建议立刻全量迁移**。推荐先 Langfuse + instructor 增强，然后选 LangGraph 或 Pydantic AI 其中之一做渐进迁移。

---

## 2. 工具调用与 Schema 验证

### 2.1 instructor ⭐ **强烈推荐 P0**

| 指标 | 数据 |
|------|------|
| GitHub | [567-labs/instructor](https://github.com/567-labs/instructor) |
| Stars (2025-05) | **12,999** ⭐ |
| 最新版本 | v1.9.x（2025 年活跃） |
| 许可证 | MIT |

**简介**：一行代码把任何 OpenAI-compatible API 升级为"结构化输出"模式。自动重试（校验失败则重发），自动处理 JSON 解析错误，与 Pydantic 深度集成。

**与本项目的具体集成**：

当前 `app/agent.py` 中 `_dispatch()` 对工具返回值做 `json.loads()`，如果 LLM 返回格式错误则静默失败。用 instructor 可以强制 `set_analysis_plan` 的参数符合 `AnalysisPlan` schema：

```python
import instructor
from app.requirements_schema import AnalysisPlan

# 在 agent.py 的 _make_client() 中
client = instructor.from_openai(
    OpenAI(api_key=api_key, base_url=DEEPSEEK_BASE_URL, http_client=http_client)
)

# 结构化提取（用于意图解析专用路由）
plan = client.chat.completions.create(
    model=MODEL,
    response_model=AnalysisPlan,
    messages=[{"role": "user", "content": user_request}],
    max_retries=3,  # 自动重试直到 Pydantic 校验通过
)
```

**集成文件**：`app/tools.py` 的 `set_analysis_plan()` 可引入 instructor 做二次校验层；`app/agent.py` 的 `_make_client()` 包装一次即可。

**缺点**：对流式生成（streaming）的支持有限；主要用于非流式结构化提取场景。

---

### 2.2 Pydantic（已在用）

项目已在 `app/requirements_schema.py` 中使用 Pydantic 的 `AnalysisPlan`。**继续强化**：  
- 为每个工具的返回值定义 `ToolResult` 模型
- 用 `model_validator` 实现跨字段联合校验（如 compare=True 时必须有 2 个 survey）
- 与 instructor 结合使用效果最佳

---

### 2.3 guardrails-ai / outlines

**guardrails-ai**（GitHub: ~4.5k ⭐）：适合 output schema + 安全过滤，但相比 instructor 更重，且主要针对英文内容的护栏检查，中文支持一般。  
**outlines**（GitHub: ~12k ⭐）：针对本地模型的受约束解码（CFG/Regex 生成），对 API 调用模式（DeepSeek remote API）收益有限。

**结论**：本项目用 instructor + Pydantic 组合已够用，不需要引入这两个库。

---

## 3. 数据分析专用 Agent 框架

### 3.1 PandasAI ⭐ **有条件推荐 P1**

| 指标 | 数据 |
|------|------|
| GitHub | [sinaptik-ai/pandas-ai](https://github.com/sinaptik-ai/pandas-ai)（注：原 gventuri/pandas-ai 已迁移） |
| Stars | ~15,000 ⭐ |
| 最新版本 | v3.x（2025 年活跃，LiteLLM 后端） |
| 许可证 | MIT |

**简介**：`df.chat("问题")` 一行代码 NL→DataFrame 操作，自动生成 pandas/plotly 代码并执行（内置 Docker 沙箱）。

**与本项目的分工建议**：  
- 本项目的 R 后端运行 SPSS 级别统计（可靠、精确）— **继续保留**
- PandasAI 适合**快速探索性查询**，如"哪个性别的满意度均值更高" → 生成 pandas 代码 → 展示数值
- **集成方式**：新增一个 Python 工具 `quick_pandas_query(question, df_path)` → 调用 PandasAI → 返回结果

```python
# app/tools.py 新增
import pandasai as pai
from pandasai_litellm.litellm import LiteLLM

def quick_pandas_query(question: str, survey_id: str) -> dict:
    """用自然语言快速查询 pandas DataFrame"""
    llm = LiteLLM(model="deepseek/deepseek-chat", api_key=DEEPSEEK_API_KEY)
    pai.config.set({"llm": llm})
    df = pai.read_csv(f"data/{survey_id}.csv")
    result = df.chat(question)
    return _ok(str(result))
```

**缺点**：PandasAI 的代码执行依赖沙箱（Docker 或进程），与现有 subprocess 模式有重叠；对复杂推断统计（回归系数、因子载荷）解释能力不如 R 后端。  
**建议**：作为探索阶段的**补充工具**，不替代 R 后端。

---

### 3.2 LIDA（微软自动可视化）⭐ **推荐 P1**

| 指标 | 数据 |
|------|------|
| GitHub | [microsoft/lida](https://github.com/microsoft/lida) |
| Stars | ~5,000 ⭐ |
| 论文 | ACL 2023 |
| 许可证 | MIT |

**简介**：LLM 驱动的可视化生成管道：数据摘要 → 可视化目标生成 → 代码生成 → 执行 → 评估修复。支持 matplotlib/seaborn/plotly/altair/d3。

**集成方式（作为工具暴露给 LLM）**：

```python
# app/tools.py 新增
from lida import Manager, llm as lida_llm

def generate_visualization(goal: str, data_path: str, library: str = "plotly") -> dict:
    """根据研究目标自动生成可视化图表"""
    lida = Manager(text_gen=lida_llm("openai",
        api_key=DEEPSEEK_API_KEY,
        api_base="https://api.deepseek.com"))
    summary = lida.summarize(data_path)
    charts = lida.visualize(
        summary=summary,
        goal=goal,
        library=library
    )
    if charts:
        charts[0].save("output/lida_chart.png")
        return _ok("图表已生成", {"chart_path": "output/lida_chart.png"})
    return _err("图表生成失败")
```

**改动文件**：`app/tools.py` + `app/agent.py` 的 `TOOL_DEFS` 增加 `generate_visualization` 定义。

**缺点**：LIDA 需要将数据摘要发送给 LLM，涉及数据隐私；对复杂统计图（如路径图、SEM 图）生成质量不如 R `ggplot2`；更新频率近期较低（2023 年论文）。

---

### 3.3 statsmodels / pingouin（Python 端统计）

**pingouin**（GitHub: [raphaelvallat/pingouin](https://github.com/raphaelvallat/pingouin)，~3.5k ⭐）：Python 的 SPSS 替代，提供 t 检验、ANOVA、相关、回归、信度分析、中介检验等，输出 pandas DataFrame，中文友好。

**与本项目的分工**：
- R 后端处理复杂分析（SEM、多元、Bootstrap）— **保留**
- pingouin 在 Python 层做**快速校验和补充**，如：快速核验 R 结果是否合理

```python
# 用 pingouin 做结果二次验证
import pingouin as pg
result = pg.ttest(x=group_a, y=group_b, paired=False)
# 对比 R ttest 结果，差异过大则告警
```

**结论**：不替换 R，而是 Python 侧增加一层 sanity check。

---

### 3.4 Vanna.ai（NL→SQL）

| 指标 | 数据 |
|------|------|
| GitHub | [vanna-ai/vanna](https://github.com/vanna-ai/vanna) |
| Stars | ~15k ⭐ |

本项目数据存在 SQLite（`data/db/survey1.db`），Vanna.ai 的 NL→SQL 能力可为 `get_variable_catalog` 和自由查询提供增强。**建议 P2 阶段评估**：为 SQLite survey 数据库添加自然语言查询接口。

---

## 4. 可视化生成 Agent

### 4.1 fg-data-profiling（原 ydata-profiling）⭐ **推荐 P1**

| 指标 | 数据 |
|------|------|
| GitHub | [ydataai/pandas-profiling](https://github.com/ydataai/pandas-profiling) |
| 包名 | `fg-data-profiling`（2025 年品牌重命名） |
| Stars | ~12,000 ⭐ |

**功能**：`df.profile_report()` 一键生成包含分布、相关、缺失值、重复行的完整 EDA HTML 报告。

**集成方式**：增强现有 `preview_data` 工具，在 EXPLORE 阶段自动触发快速 profiling：

```python
# app/tools.py 中增强 preview_data()
from data_profiling import ProfileReport  # 新包名

def preview_data(file_path=None, n_rows=5, state=None) -> dict:
    df = pd.read_csv(file_path)
    # 原有逻辑...
    # 新增：如果行数 < 5000，自动生成 profiling
    if len(df) < 5000:
        profile = ProfileReport(df, title="快速数据探索", minimal=True)
        profile.to_file("output/eda_report.html")
    return _ok(summary, {"eda_report": "output/eda_report.html"})
```

---

### 4.2 AutoViz / Lux

**AutoViz**（GitHub: ~1.5k ⭐）：自动选择最佳图表类型，适合快速无代码可视化，但功能较简单。  
**Lux**（GitHub: ~5k ⭐）：Jupyter 内 DataFrame 自动推荐可视化，不适合 Streamlit + Rscript 架构。  

**结论**：这两个项目维护活跃度下降，不推荐引入。LIDA + fg-data-profiling 组合更优。

---

## 5. 评估与可观测性（Eval & Observability）

### 5.1 Langfuse ⭐ **强烈推荐 P0**

| 指标 | 数据 |
|------|------|
| GitHub | [langfuse/langfuse](https://github.com/langfuse/langfuse) |
| Stars | ~12,000 ⭐（增长极快，YC W23） |
| 许可证 | MIT（可自部署） |
| 最新版本 | v3.x（2025 年活跃） |

**简介**：开源 LLM 可观测平台，提供 trace 追踪、span 嵌套、token 成本统计、评估打分、prompt 版本管理。支持 Docker 自部署（完全私有）。

**与本项目的直接价值**：  
- 追踪每轮 ReAct 的 `tool_call → tool_result` 链路
- 统计每个工具（`run_analysis_module`、`run_report` 等）的失败率
- 分析 DeepSeek v4-pro 的 `reasoning_content` 长度与 token 成本的关系

**集成方式（最小侵入，约 30 分钟）**：

```python
# app/agent.py 顶部加入
from langfuse import Langfuse
from langfuse.openai import openai as langfuse_openai

langfuse = Langfuse()  # 读取 LANGFUSE_SECRET_KEY, LANGFUSE_PUBLIC_KEY

def _make_client() -> OpenAI:
    # 改为 langfuse_openai.OpenAI，自动拦截所有 API 调用
    return langfuse_openai.OpenAI(
        api_key=api_key,
        base_url=DEEPSEEK_BASE_URL,
        http_client=httpx.Client(transport=httpx.HTTPTransport())
    )
```

同时可在 `app/hooks.py` 的 `log_event()` 中添加 Langfuse span：

```python
# hooks.py 增强
trace = langfuse.trace(name="agent_turn")
span = trace.span(name=f"tool:{name}", input=inputs)
# ... 执行后
span.end(output=result, status_message=result.get("status"))
```

**改动文件**：`app/agent.py`（4 行）+ `app/hooks.py`（可选增强）  
**部署**：`docker compose up langfuse` 本地运行，或用免费云版。

---

### 5.2 Phoenix（Arize）⭐ **推荐 P1**

| 指标 | 数据 |
|------|------|
| GitHub | [Arize-ai/phoenix](https://github.com/Arize-ai/phoenix) |
| Stars | ~8,000 ⭐ |
| 许可证 | Apache 2.0 |

**简介**：基于 OpenTelemetry 的 AI 可观测平台，内置 LLM eval（相关性、幻觉检测）、数据集管理、实验对比。支持 LangGraph/CrewAI/DSPy 的自动 instrumentation。

**与 Langfuse 的选择**：  
- **Langfuse**：更轻量，prompt 管理更强，中文界面友好，推荐中小团队
- **Phoenix**：eval 能力更强（RAG 相关性评分）、OTel 标准化更好，推荐研究型场景

**本项目建议**：优先 Langfuse（更快集成），Phoenix 作为备选。

---

### 5.3 其他可观测工具

| 工具 | Stars | 推荐度 | 备注 |
|------|-------|--------|------|
| LangSmith | N/A（SaaS） | P2 | 与 LangGraph 深度集成，但需要云服务，隐私风险 |
| Helicone | ~2k ⭐ | P2 | OpenAI API 代理模式，侵入性极低 |
| OpenLLMetry | ~3k ⭐ | P2 | OpenTelemetry 标准，未来兼容性好 |
| TruLens | ~2k ⭐ | P3 | RAG eval 专用，当前无 RAG 需求暂不优先 |

---

## 6. RAG / 文档检索

**应用场景**：读取问卷调研材料（PDF/Word 版问卷设计书、变量字典 Excel、SPSS 编码手册），让 Agent 在推理时能查询变量含义和编码规则。

### 6.1 LanceDB ⭐ **推荐 P1**

| 指标 | 数据 |
|------|------|
| GitHub | [lancedb/lancedb](https://github.com/lancedb/lancedb) |
| Stars | ~15,000 ⭐ |
| 许可证 | Apache 2.0 |

**简介**：嵌入式向量数据库（无服务端进程），基于 Lance 列式格式。Python 侧 `import lancedb` 即用，数据存本地文件。适合单机部署的数据分析工具。

**集成方式**：新增 `app/rag.py`，为变量字典建立向量索引：

```python
import lancedb
import pandas as pd

def build_variable_index(survey_id: str):
    db = lancedb.connect("data/vectordb")
    # 从 SQLite variables 表读取变量标签
    conn = sqlite3.connect(f"data/db/{survey_id}.db")
    vars_df = pd.read_sql("SELECT name, label, value_labels FROM variables", conn)
    # 生成 embedding 并存入 LanceDB
    table = db.create_table("variables", data=vars_df.to_dict("records"))

def search_variable(query: str, survey_id: str, n: int = 5) -> list:
    db = lancedb.connect("data/vectordb")
    table = db.open_table("variables")
    results = table.search(query).limit(n).to_list()
    return results
```

`get_variable_catalog` 工具可增加语义搜索模式，当变量数量 > 500 时尤其有价值。

---

### 6.2 Chroma

| 指标 | 数据 |
|------|------|
| GitHub | [chroma-core/chroma](https://github.com/chroma-core/chroma) |
| Stars | ~18,000 ⭐ |

轻量嵌入式向量库，API 极简（4 个核心方法），适合快速原型。与 LanceDB 的选择：  
- LanceDB：更快、支持 SQL 过滤、适合大数据集（问卷变量字典 + 文档）
- Chroma：更易上手，社区文档更丰富

**本项目推荐 LanceDB**（更轻量，无需额外服务，嵌入式）。

---

### 6.3 Unstructured.io（文档解析）

| 指标 | 数据 |
|------|------|
| 官网 | [unstructured.io](https://unstructured.io) |
| GitHub | [Unstructured-IO/unstructured](https://github.com/Unstructured-IO/unstructured) |
| Stars | ~10,000 ⭐ |

**功能**：解析 PDF/Word/Excel/PPT 等格式，提取结构化文本块（标题、表格、段落）。适合读取问卷设计书、SPSS 编码手册。

```python
from unstructured.partition.auto import partition

def ingest_survey_document(doc_path: str) -> list[str]:
    """将 PDF/Word 问卷文档切割成文本块，入库 LanceDB"""
    elements = partition(filename=doc_path)
    return [str(el) for el in elements if len(str(el)) > 50]
```

**改动文件**：新增 `app/rag.py`，`app/tools.py` 增加 `ingest_document` 和 `search_document` 工具。

---

### 6.4 Qdrant

| 指标 | 数据 |
|------|------|
| GitHub | [qdrant/qdrant](https://github.com/qdrant/qdrant) |
| Stars | ~22,000 ⭐ |

Rust 编写，高性能，支持分布式部署。对于本项目（单机、中小数据量），Qdrant 是**过度设计**，不推荐。

---

## 7. Prompt 工程与版本管理

### 7.1 当前问题

`agent/system_prompt.md` 是硬编码的 Markdown 文件，改动无版本追踪，无法 A/B 测试，无法回滚。

### 7.2 Langfuse Prompt Management ⭐ **推荐（与 P0 的 Langfuse 合并）**

Langfuse 内置 prompt 版本管理，可在 Web UI 中编辑、标记版本、A/B 测试：

```python
# app/agent.py
def _load_system_prompt() -> str:
    if USE_LANGFUSE:
        prompt = langfuse.get_prompt("survey-analysis-system", version="latest")
        return prompt.compile()  # 支持变量插值
    return SYSTEM_PROMPT_PATH.read_text()
```

**优势**：无需改代码就能更新 prompt；完整的 git-style 历史；A/B 实验。

---

### 7.3 DSPy（P2，更激进方案）

如 §1.6 所述，DSPy 可以将 system prompt 完全替换为可自动优化的 Module。**适合 P2 阶段**，前提是积累了足够的评估数据集（至少 50-100 个 labeled examples）。

---

### 7.4 Promptfoo

| GitHub | [promptfoo/promptfoo](https://github.com/promptfoo/promptfoo) | ~5k ⭐ |

命令行 prompt 评估工具，支持多 prompt 并行测试、LLM-as-judge。可以作为 CI/CD 中的 prompt 回归测试工具：

```yaml
# promptfooconfig.yaml
prompts:
  - file://agent/system_prompt.md
  - file://agent/system_prompt_v2.md
providers:
  - id: deepseek:deepseek-chat
    config: {apiBaseUrl: "https://api.deepseek.com"}
tests:
  - vars:
      user_input: "分析第一份调查的描述统计"
    assert:
      - type: contains
        value: "set_analysis_plan"
```

**集成路径**：添加 `.github/workflows/prompt-eval.yml`，PR 时自动跑评估。

---

## 8. 多 Agent / Subagent 模式

### 8.1 是否值得拆分子角色？

**当前架构**：单 Agent + 11 个工具 + Phase 路由（实际上已有隐式分工）。

**潜在子角色拆分**：
1. **数据侦察员**（EXPLORE phase）：读变量字典、预览数据
2. **统计学家**（ANALYZE phase）：选择模块、解读结果
3. **可视化设计师**：生成和优化图表
4. **报告撰写员**（REPORT phase）：撰写解读文字、Quarto 渲染

**评估结论**：  
对于当前规模（11 工具，12 分析模块），**单 Agent + Phase 路由已经足够有效**。拆分为多 Agent 会增加协调开销（跨 Agent 状态同步、防止幻觉传播）。

**建议**：当分析模块扩展到 30+ 工具或需要并行分析时，再考虑引入 CrewAI Flows 或 LangGraph 多节点并发。

---

### 8.2 CrewAI Flows（未来多 Agent 方案）

若要拆分，CrewAI Flows 是比 CrewAI Crew 更适合的选择（事件驱动、精确控制）：

```python
from crewai.flow.flow import Flow, listen, start

class SurveyAnalysisFlow(Flow):
    @start()
    def intake_phase(self):
        return DataScoutAgent().run(self.state["user_request"])
    
    @listen(intake_phase)
    def analysis_phase(self, scout_output):
        return StatisticianAgent().run(scout_output)
    
    @listen(analysis_phase)  
    def report_phase(self, analysis_output):
        return ReportWriterAgent().run(analysis_output)
```

---

## 9. 代码执行沙箱

### 9.1 现状评估

`app/tools.py` 的 `_run()` 函数直接用 `subprocess.run()` 调用 `Rscript`，在项目根目录执行。**当前场景**（工具由 LLM 调用但 R 脚本是固定的、不由 LLM 生成）相对安全。

**风险升级条件**：如果引入"LLM 生成 R 代码然后执行"（如 LIDA 生成 ggplot 代码），则必须引入沙箱。

---

### 9.2 E2B ⭐ **推荐（条件触发，P2）**

| 指标 | 数据 |
|------|------|
| GitHub | [e2b-dev/E2B](https://github.com/e2b-dev/e2b) |
| Stars | ~7,000 ⭐ |
| 许可证 | Apache 2.0（SDK），商业 SaaS |

**简介**：云端隔离沙箱，支持 Python/R/Shell，秒级启动，Python SDK 调用极简。

```python
from e2b_code_interpreter import Sandbox

def run_r_code_safe(r_code: str) -> dict:
    """在隔离沙箱中执行 LLM 生成的 R 代码"""
    with Sandbox() as sandbox:
        # 安装 R 依赖
        sandbox.commands.run("Rscript -e 'install.packages(\"ggplot2\")'")
        # 执行代码
        result = sandbox.commands.run(f"Rscript -e '{r_code}'")
        return {"stdout": result.stdout, "stderr": result.stderr}
```

**取舍**：
- ✅ 云端隔离，LLM 生成的恶意代码无法逃逸
- ❌ 需要网络请求（延迟增加 500ms~2s）
- ❌ 云服务费用（$0.04/小时 sandbox）
- ❌ 无法访问本地 `data/db/*.db` 文件（需先上传）

**结论**：当前固定 Rscript 路径无需沙箱。**若添加 LLM 生成代码功能时，E2B 是首选**。

---

### 9.3 Jupyter Kernel Gateway（本地方案）

适合完全本地部署：启动一个 Jupyter kernel，通过 WebSocket 执行代码，获得完整的状态保持（变量跨 cell 持久化）。

```bash
pip install jupyter_kernel_gateway
jupyter kernelgateway --port 8888
```

**优势**：本地运行，可访问本地文件；R kernel 也支持（IRkernel）。  
**适合场景**：希望 LLM 生成 R/Python 代码、逐步执行、保持变量状态的交互式分析。

---

## 10. UI 框架替代/增强

### 10.1 评估：是否要切换 Streamlit？

**结论：不建议切换，用 Components 增强**。

Streamlit 在数据分析工具领域的生态成熟，项目 `app/ui/` 已有一定开发量，切换成本高。

### 10.2 Streamlit Components 增强推荐

| 组件 | 功能 | 推荐度 |
|------|------|--------|
| **streamlit-aggrid** | Excel 风格的交互式数据表格，支持排序/筛选/编辑 | ⭐⭐⭐⭐⭐ P0 |
| **streamlit-elements** | 拖拽 dashboard（基于 Material UI + react-grid-layout） | ⭐⭐⭐ P1 |
| **streamlit-extras** | 丰富的 UI 增强（metric_row、badges、switch 等） | ⭐⭐⭐⭐ P1 |
| **streamlit-plotly-events** | Plotly 图表点击/hover 事件回调 | ⭐⭐⭐⭐ P1 |
| **streamlit-ace** | 代码编辑器组件（显示生成的 R 代码） | ⭐⭐⭐ P2 |

**具体集成建议**：
- `streamlit-aggrid` → 替换当前的 `st.dataframe`，让用户能交互式筛选变量目录
- `streamlit-plotly-events` → 用户点击图表中的数据点，触发 Agent 深度分析

---

### 10.3 其他框架简评

| 框架 | Stars | 评估 |
|------|-------|------|
| **Gradio** | ~36k ⭐ | ML 演示友好，但不如 Streamlit 适合复杂数据分析 workflow |
| **Reflex** | ~23k ⭐ | 全栈 Python，响应式，适合需要更复杂 UI 的场景，迁移成本高 |
| **NiceGUI** | ~12k ⭐ | Python 原生 Vue 风格，实时通信好，但生态较小 |
| **Panel/HoloViz** | ~5k ⭐ | 与 Bokeh/Plotly/Matplotlib 深度集成，科学可视化专长 |
| **Mesop (Google)** | ~6k ⭐ | Google 出品，Python → Web 组件，尚不成熟 |

---

## 11. 报告/文档生成

### 11.1 Quarto（现有）— 继续加强

现有 `run_report` 调用 `quarto render`，输出 HTML。**扩展方向**：

```yaml
# 04-report/report.qmd - 扩展输出格式
format:
  html:
    toc: true
    theme: cosmo
    code-fold: true
  docx:
    reference-doc: templates/report_template.docx  # 新增 Word 输出
  pdf:
    documentclass: ctexart  # 新增中文 PDF 输出
    CJKmainfont: "Source Han Sans"
```

只需修改 `04-report/report.qmd` 的 YAML front-matter，无需改 Python 代码。

---

### 11.2 Typst ⭐ **推荐 P1（中文 PDF 生成）**

| 指标 | 数据 |
|------|------|
| GitHub | [typst/typst](https://github.com/typst/typst) |
| Stars | ~40,000 ⭐ |
| 特点 | 毫秒级编译，原生中文支持，比 LaTeX 简单 100 倍 |

**与 Quarto 的分工**：
- Quarto → HTML 交互报告（现有，保留）
- Typst → 精美的 PDF 正式报告（新增）

Quarto 0.4+ 已支持 Typst 作为 PDF 后端（替代 LaTeX）：

```yaml
# 04-report/report_formal.qmd
format:
  typst:
    font-paths: ["fonts/"]  # 思源字体目录
    mainfont: "Source Han Serif SC"
    section-numbering: "1.1"
```

**优势**：比 `xelatex` 快 10 倍；中文字体配置简单；Quarto 原生支持无需额外工具链。

---

### 11.3 python-docx（Word 直接生成）

```python
# app/tools.py 新增
from docx import Document
from docx.shared import Inches

def generate_word_report(compiled_results: dict) -> dict:
    """从 compiled.rds 结果直接生成 Word 报告"""
    doc = Document("templates/report_template.docx")
    # 填充统计表格
    for module, result in compiled_results.items():
        doc.add_heading(module, level=2)
        table = doc.add_table(rows=1, cols=len(result["headers"]))
        # ...
    doc.save("output/reports/report.docx")
    return _ok("Word 报告已生成")
```

**适用场景**：用户需要可编辑的 Word 文档（如需要手动标注、领导审批）。

---

## 12. 中文/本地化支持

### 12.1 LLM 中文优化

当前使用 DeepSeek v4-pro，**中文能力已是业界最优**，无需切换。备选方案：
- **Qwen3**（阿里，2025 年最新，32B/72B）：中文理解略逊于 DeepSeek，但推理能力强；适合作备用
- **智谱 GLM-4**：中文对话友好，API 可用，但工具调用能力稍弱

---

### 12.2 中文字体处理

**推荐字体方案**：

```bash
# 安装思源字体（免费、开源）
apt-get install fonts-noto-cjk  # Ubuntu
brew install font-source-han-sans  # macOS
```

在 Quarto/Typst 报告中：
```yaml
# Quarto PDF
pdf-engine: xelatex
CJKmainfont: "Noto Serif CJK SC"
CJKsansfont: "Noto Sans CJK SC"
```

R 绘图中文字体：
```r
# 02-analyze/ 中的 R 脚本
library(showtext)
font_add_google("Noto Serif SC", "noto")
showtext_auto()
```

---

### 12.3 jieba / HanLP（分词，可选）

如果引入文本分析模块（开放题分析、词频统计），可以添加 jieba 作为新工具：

```python
# app/tools.py 潜在新工具
import jieba
from collections import Counter

def text_analysis(survey_id: str, column: str) -> dict:
    """对开放题文本进行中文词频分析"""
    df = pd.read_sql(f"SELECT {column} FROM survey", conn)
    words = []
    for text in df[column].dropna():
        words.extend(jieba.cut(text, cut_all=False))
    freq = Counter(w for w in words if len(w) > 1)
    return _ok("词频分析完成", {"top_words": freq.most_common(20)})
```

---

## 13. SPSS / 问卷专用生态

### 13.1 pyreadstat ⭐ **强烈推荐 P0**

| 指标 | 数据 |
|------|------|
| GitHub | [Roche/pyreadstat](https://github.com/Roche/pyreadstat) |
| Stars | ~700 ⭐ |
| 功能 | 读写 .sav/.por/.sas7bdat/.dta 文件 |

**现状**：当前项目通过 Excel 中间格式导入数据，存在编码信息丢失（变量标签、值标签、测量水平）。

**直接价值**：

```python
import pyreadstat

def import_spss_file(sav_path: str) -> dict:
    """直接读取 .sav 文件，保留所有元数据"""
    df, meta = pyreadstat.read_sav(sav_path)
    
    # meta 包含:
    # meta.variable_labels: {"q1": "您的性别", "q2": "您的年龄"}
    # meta.value_labels: {"q1": {1: "男", 2: "女"}}
    # meta.variable_measure: {"q1": "nominal", "q2": "scale"}
    
    # 直接写入 SQLite，无需 Excel 转换步骤
    df.to_sql("survey", conn, if_exists="replace")
    
    # 将 meta 存入 variables 表
    for var_name, label in meta.variable_labels.items():
        cursor.execute(
            "INSERT INTO variables VALUES (?, ?, ?, ?)",
            (var_name, label, meta.variable_measure.get(var_name), 
             json.dumps(meta.value_labels.get(var_name, {})))
        )
    return _ok(f"已导入 {len(df)} 行 × {len(df.columns)} 列")
```

**改动文件**：
- `app/tools.py`：新增 `import_spss_file()` 工具，修改 `run_clean()` 支持 .sav 输入
- `app/agent.py` TOOL_DEFS：增加 `import_spss_file` 定义
- `app/router.py`：在 EXPLORE phase 暴露新工具

---

### 13.2 haven（R 包，已可用）

R 的 `haven` 包可以读 .sav 文件（`read_spss()`），并自动处理 labelled 类型。若 Python 层用 pyreadstat 入库有困难，可以让 R 脚本直接读 .sav：

```r
# 01-clean/clean.R
library(haven)
df <- read_spss("data/raw/survey.sav")
# haven 自动保留 label 属性
```

---

### 13.3 survey（R 包，复杂抽样）⭐ **推荐 P1**

R 的 `survey` 包支持加权调查数据分析（Horvitz-Thompson 估计、设计效应、校准权重）。如果调研数据有抽样权重，所有统计结论都应使用加权分析：

```r
# 新增 02-analyze/weighted_descriptives.R
library(survey)
design <- svydesign(ids=~PSU, weights=~WEIGHT, data=df)
svymean(~satisfaction, design)  # 加权均值
svytable(~gender+satisfaction, design)  # 加权交叉表
```

**在 `app/state.py` 中添加 `weight_var` 字段**，`AnalysisPlan` 增加 `weight_variable` 参数。

---

### 13.4 pingouin

| GitHub | [raphaelvallat/pingouin](https://github.com/raphaelvallat/pingouin) | ~3.5k ⭐ |

Python 侧统计检验库，`pingouin.ttest()` 输出比 scipy 更丰富（效应量 Cohen's d、BF10、功效分析）。**建议作为 R 结果的 Python 验证层**，不替换 R 后端。

---

### 13.5 总结：应 wrap 成工具的库

| 库 | 语言 | 当前状态 | 建议 |
|----|------|---------|------|
| pyreadstat | Python | 未使用 | **P0 必加：直接读 .sav** |
| haven | R | 未使用 | P1 加：R 端读 .sav 备选 |
| survey (R) | R | 未使用 | P1 加：加权分析模块 |
| pingouin | Python | 未使用 | P2：结果验证工具 |
| PandasAI | Python | 未使用 | P1：快速 NL 查询工具 |
| LIDA | Python | 未使用 | P1：可视化生成工具 |
| fg-data-profiling | Python | 未使用 | P1：增强 preview_data |
| jieba | Python | 未使用 | P2：文本分析新模块 |

---

## 推荐落地路线图

### 阶段 1：P0（本月，约 3-5 天工作量）

**目标**：零架构改动，立刻获得可观测性 + 输入校验增强 + SPSS 直接导入

#### Week 1 任务清单

```
Day 1-2: Langfuse 集成
  - pip install langfuse
  - app/agent.py: _make_client() 改为 langfuse_openai.OpenAI（4行）
  - app/hooks.py: log_event() 同时发 Langfuse span
  - 配置 LANGFUSE_SECRET_KEY 环境变量（docker compose 本地部署）
  - 验证：跑一次完整分析，在 Langfuse Dashboard 看到 trace

Day 3: instructor 集成
  - pip install instructor
  - app/agent.py: 可选路径——意图解析时用 instructor 强制 AnalysisPlan schema
  - app/tools.py: set_analysis_plan 的 Pydantic 校验已有，加 max_retries=3

Day 4-5: pyreadstat + .sav 直接导入
  - pip install pyreadstat
  - app/tools.py: 新增 import_spss_file() 工具
  - app/agent.py TOOL_DEFS: 增加定义
  - app/router.py: EXPLORE phase 暴露新工具
  - 测试：用真实 .sav 文件验证元数据保留

Day 5: fg-data-profiling 增强 preview_data
  - pip install fg-data-profiling
  - app/tools.py: preview_data() 增加 ProfileReport 生成
  - Streamlit UI: 增加 EDA 报告链接展示
```

---

### 阶段 2：P1（1-2 月，约 10-15 天工作量）

**目标**：架构增强，引入 RAG、可视化生成、LangGraph 升级

#### 月度任务

```
Month 1:

Week 1-2: LangGraph 迁移（或 Pydantic AI，二选一）
  - 评估：跑一个 mini-PoC，对比 LangGraph vs Pydantic AI 开发体验
  - 建议先 Pydantic AI（更简单），LangGraph 保留为 Phase 2b
  - 改动: app/agent_v2.py（新建，保留 agent.py 作回退）
  - 验证: 所有 11 个工具在新框架下通过测试

Week 3: LanceDB + RAG 构建
  - pip install lancedb unstructured
  - 新建 app/rag.py: 变量字典向量化入库
  - app/tools.py: 新增 search_variable(), search_document()
  - 集成到 get_variable_catalog（语义检索模式）

Week 4: LIDA 可视化工具
  - pip install lida
  - app/tools.py: 新增 generate_visualization()
  - app/agent.py: 在 ANALYZE phase 暴露工具
  - Streamlit UI: 展示 LIDA 生成的图表

Month 2:

Week 1: Quarto 多格式输出
  - 04-report/report.qmd: 增加 docx + typst PDF 输出格式
  - app/tools.py: run_report() 增加 format 参数
  - 安装思源字体，测试中文 PDF 输出

Week 2: survey R 包（加权分析模块）
  - 02-analyze/weighted_descriptives.R: 新建
  - app/requirements_schema.py: AnalysisPlan 增加 weight_variable 字段
  - app/state.py: AppState 增加 weight_var
  - 测试带权重的调查数据

Week 3-4: streamlit-aggrid + plotly events
  - pip install streamlit-aggrid streamlit-plotly-events
  - app/ui/: 升级变量目录展示为 AgGrid
  - 图表点击 → 触发深度分析 Agent
```

---

### 阶段 3：P2（长期，按需引入）

**目标**：高级功能，探索性技术储备

```
DSPy Prompt 优化
  - 积累 100+ 评估案例（正确/错误的工具调用序列）
  - 用 DSPy MIPROv2 自动优化 system_prompt
  - A/B 测试：DSPy 优化后 vs 手写 system_prompt

多 Agent 架构（若工具数量 > 30）
  - 引入 CrewAI Flows 或 LangGraph 多节点并发
  - 拆分: DataScout / Statistician / Visualizer / ReportWriter

E2B 沙箱（若引入 LLM 生成代码功能）
  - 当 generate_r_code() 类工具上线时，必须切换到 E2B 或 Jupyter Kernel Gateway

Vanna.ai NL→SQL
  - 为 survey SQLite 数据库建立 NL 查询接口
  - 用户可以直接用中文问"满意度在不同城市的分布"

文本分析模块（开放题）
  - jieba 分词 + 词云 + 情感分析
  - 新增 text_analysis 工具
```

---

## 附录：现有代码架构与框架映射

```
现有组件                    推荐迁移/增强方向
─────────────────────────────────────────────────
app/agent.py                → LangGraph 状态图 / Pydantic AI Agent
  _make_client()            → + Langfuse 包装（P0）
  run_agent_turn()          → 变为 graph.invoke() / agent.run()
  _dispatch()               → 保留，作为工具执行层

app/router.py               → LangGraph 的条件边函数（结构不变）
  determine_phase()         → graph.add_conditional_edges() 的 condition fn

app/hooks.py                → LangGraph 节点 / Pydantic AI RunContext
  pre_tool_use()            → 保留为 gate 节点
  log_event()               → + Langfuse span 发送（P0）

app/tools.py                → 增加新工具（pyreadstat, LIDA, fg-profiling, RAG）
  _run() subprocess         → 保留（固定 R 脚本安全）
                            → E2B 替换（当 LLM 生成代码时）

app/state.py                → TypedDict 扩展（LangGraph 需要）
  AppState                  → 增加 weight_var, rag_index_built 字段

agent/system_prompt.md      → + Langfuse Prompt 版本管理
                            → DSPy Module（P2）

04-report/report.qmd        → 增加 typst PDF + docx 输出格式
```

---

## 参考资料

### Agent 编排框架
- LangGraph: https://github.com/langchain-ai/langgraph | https://docs.langchain.com/oss/python/langgraph/overview
- Pydantic AI: https://github.com/pydantic/pydantic-ai | https://ai.pydantic.dev
- CrewAI: https://github.com/crewAIInc/crewAI | https://docs.crewai.com
- Microsoft AutoGen (维护模式): https://github.com/microsoft/autogen
- Microsoft Agent Framework (MAF): https://github.com/microsoft/agent-framework | https://learn.microsoft.com/en-us/agent-framework/
- DSPy: https://github.com/stanfordnlp/dspy | https://dspy.ai
- OpenAI Agents SDK: https://github.com/openai/openai-agents-python

### 工具调用与结构化输出
- instructor: https://github.com/567-labs/instructor | https://python.useinstructor.com
- Pydantic: https://docs.pydantic.dev

### 数据分析专用
- PandasAI (新仓库): https://github.com/sinaptik-ai/pandas-ai
- LIDA: https://github.com/microsoft/lida | https://microsoft.github.io/lida/
- pingouin: https://pingouin-stats.org | https://github.com/raphaelvallat/pingouin
- pyreadstat: https://github.com/Roche/pyreadstat

### 可观测性
- Langfuse: https://github.com/langfuse/langfuse | https://langfuse.com
- Phoenix (Arize): https://github.com/Arize-ai/phoenix | https://arize.com/docs/phoenix
- Promptfoo: https://github.com/promptfoo/promptfoo | https://promptfoo.dev

### RAG / 向量库
- LanceDB: https://github.com/lancedb/lancedb | https://lancedb.github.io/lancedb/
- Chroma: https://github.com/chroma-core/chroma | https://docs.trychroma.com
- Qdrant: https://github.com/qdrant/qdrant | https://qdrant.tech
- Unstructured: https://github.com/Unstructured-IO/unstructured | https://unstructured.io

### 代码执行沙箱
- E2B: https://github.com/e2b-dev/e2b | https://e2b.dev/docs
- Jupyter Kernel Gateway: https://jupyter-kernel-gateway.readthedocs.io

### 报告生成
- Quarto: https://quarto.org
- Typst: https://github.com/typst/typst | https://typst.app
- python-docx: https://python-docx.readthedocs.io

### 数据探索
- fg-data-profiling (原 ydata-profiling): https://github.com/ydataai/pandas-profiling
- R survey 包: https://cran.r-project.org/web/packages/survey/index.html
- R haven 包: https://haven.tidyverse.org

### Streamlit 增强
- streamlit-aggrid: https://github.com/PablocFonseca/streamlit-aggrid
- streamlit-extras: https://github.com/arnaudmiribel/streamlit-extras

---

*调研时间：2025 年 5 月。Star 数据来源：GitHub API（2025-05-22 实时查询）。所有推荐均基于项目现有代码架构（`app/agent.py`、`app/router.py`、`app/hooks.py`、`app/tools.py`、`app/state.py`）的具体分析。*