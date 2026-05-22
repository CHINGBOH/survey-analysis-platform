# Langfuse 可观测性集成 — 技术文档

> 本项目通过 `app/observability.py` 接入 Langfuse 4.x,实现 Agent + LLM + 工具调用的全链路追踪,**零侵入降级**:不配置环境变量时全部 API 自动 no-op,主流程不变。

---

## 1. 为什么需要

| 痛点 | 没有可观测性 | 有 Langfuse |
| --- | --- | --- |
| 用户报错复现 | 翻 `logs/events.jsonl` 逐行猜 | UI 直接看 trace 树状回放 |
| Token 成本归因 | 看 DeepSeek 账单看不出谁烧的 | 按 `session_id` / `user_id` / `tags` 分摊 |
| Reasoning Token 透明度 | 不知道烧了多少 reasoning | 自动捕获 `output_reasoning_tokens` |
| 多轮对话调试 | 看不到完整链路 | Sessions 视图按 `sap-xxx` 聚合整段对话 |
| Prompt 迭代 | 改完靠感觉 | 同一份数据集跑两版 prompt 对比 |
| Bad case 归集 | 散落各处 | Score(👍👎)+ Dataset 一键导出 |

---

## 2. 架构

```
┌─────────────────── Streamlit ──────────────────┐
│ main.py                                        │
│   ├─ trace_session_id = "sap-{uuid12}"   ← Session 维度键
│   └─ run_agent_turn(api_messages, state,       │
│                     session_id=..., user_id=...)
└────────────────────────────────────────────────┘
                       │
                       ▼
┌──────────────── app/agent.py ──────────────────┐
│ start_turn(name="survey-analysis.chat-turn",   │  ← Langfuse AGENT 观察
│            user_input=<last_user_msg>,         │
│            metadata={model, phase, n_msgs},    │
│            session_id, user_id,                │
│            tags=["survey-analysis","chat"])    │
│   │                                            │
│   ├─ wrap_openai_client(OpenAI(...))           │  ← langfuse.openai drop-in
│   │     └─ DeepSeek 调用自动产生 GENERATION 子观察
│   │        (含 model, tokens, reasoning_tokens, cache_hit)
│   │                                            │
│   ├─ _dispatch(tool_name, args, trace=...)     │
│   │     └─ record_tool_call → TOOL 子观察       │
│   │        record_tool_result → 写 output      │
│   │                                            │
│   └─ end_turn(handle, output={rounds}, status) │  ← flush 到 Langfuse
└────────────────────────────────────────────────┘
                       │
                       ▼
           https://cloud.langfuse.com
           (OpenTelemetry over HTTPS)
```

**关键设计**:
- 用 `start_as_current_observation` 进入 OTel context,langfuse.openai 自动把 GENERATION 嵌套到 AGENT 下(否则会各自起 trace)
- 用 `propagate_attributes` 把 `session_id` / `user_id` / `tags` 向下传播,所有子观察继承
- 同步生成器主流程不变,Langfuse 内部走 OTel 异步导出,**不阻塞 LLM 调用**
- 失败/未启用一律退化为 `_NullSpan`(`__getattr__` 返回 no-op lambda)

---

## 3. 环境变量

```bash
# 必填 — 缺任一即降级为 no-op
LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxx
LANGFUSE_SECRET_KEY=sk-lf-xxxxxxxx

# 二选一(优先 HOST,兼容 BASE_URL)
LANGFUSE_HOST=https://cloud.langfuse.com           # EU cloud
# LANGFUSE_HOST=https://us.cloud.langfuse.com      # US cloud
# LANGFUSE_HOST=http://localhost:3000              # 自托管
LANGFUSE_BASE_URL=https://cloud.langfuse.com       # alias
```

获取 key: Langfuse UI → Settings → API Keys → Create new key

---

## 4. 收费

| 方案 | 价格 | 限额 | 适合 |
| --- | --- | --- | --- |
| **Hobby (Cloud)** | **0** | 50k observations/月、30 天保留、1 项目、2 用户 | 个人/原型 |
| Pro (Cloud) | $59/月起 | 100k obs,90 天保留 | 小团队 |
| Team (Cloud) | $499/月起 | SLA + SSO | 企业 |
| **Self-hosted (OSS)** | **0** | 无限 | 隐私敏感/无外网 |

本项目当前使用 Hobby。按每次对话 5 个 observation 估算,Hobby 可承载 ~333 次/天。

---

## 5. API 速查

### `app/observability.py` 公开接口

| 函数 | 用途 | 失败行为 |
| --- | --- | --- |
| `is_enabled() -> bool` | 检查是否已初始化 | 返回 `False` |
| `wrap_openai_client(client) -> client` | 包装 OpenAI client 为 langfuse drop-in | 返回原 client |
| `start_turn(name, user_input, metadata, session_id, user_id, tags) -> handle` | 开 root AGENT 观察 | 返回 `_NULL_SPAN` |
| `record_tool_call(parent, tool_name, inputs) -> ctx manager` | 在 with 块内创建 TOOL 子观察 | yield `_NULL_SPAN` |
| `record_tool_result(span, result)` | 写 tool 结果(status/summary) | no-op |
| `end_turn(handle, output, status)` | 关 AGENT 观察 + flush | no-op |

### 标准调用模式

```python
from app.observability import (
    start_turn, end_turn,
    record_tool_call, record_tool_result,
    wrap_openai_client,
)

client = wrap_openai_client(OpenAI(api_key=..., base_url=...))

handle = start_turn(
    name="survey-analysis.chat-turn",
    user_input=user_msg[:500],
    metadata={"model": MODEL, "phase": state.phase},
    session_id="sap-abc123",
    user_id="cli-l",
    tags=["survey-analysis", "chat"],
)
try:
    # ... LLM 调用(自动产生 GENERATION 子观察)
    resp = client.chat.completions.create(...)

    # 工具调用
    with record_tool_call(handle, "run_descriptives", {"survey":"s1"}) as sp:
        result = run_descriptives(...)
        record_tool_result(sp, result)

    end_turn(handle, output={"rounds": n}, status="ok")
except Exception as e:
    end_turn(handle, output={"error": str(e)}, status="error")
    raise
```

---

## 6. Langfuse 数据模型映射

| 项目概念 | Langfuse 概念 | 字段示例 |
| --- | --- | --- |
| Streamlit 会话 | **Session** | `sap-a3f9b8c1d2e0` |
| 一次用户提问 → 多轮 LLM/tool | **Trace** | name=`survey-analysis.chat-turn` |
| Agent 根观察 | **Observation (AGENT)** | input=用户消息, metadata={model,phase} |
| DeepSeek API 调用 | **Observation (GENERATION)** | model, tokens (input/output/reasoning/cache), cost |
| 一次工具调用 | **Observation (TOOL)** | name=`tool:run_clean`, input/output |
| 用户/标签维度 | `user_id`, `tags` | `cli-l`, `["survey-analysis","chat"]` |

---

## 7. 已实现的 instrumentation 基线

参考 `github.com/langfuse/skills` 的 `instrumentation.md`:

| 基线项 | 状态 | 实现位置 |
| --- | --- | --- |
| Model name | ✅ 自动 | `langfuse.openai` drop-in |
| Token usage(含 reasoning + cache) | ✅ 自动 | `langfuse.openai` drop-in |
| 描述性 trace 名 | ✅ | `survey-analysis.chat-turn` |
| Span 层级 | ✅ | AGENT > GENERATION/TOOL |
| 观察类型 | ✅ | `agent`/`tool`/`generation` |
| 敏感数据 | ⚠️ | 暂无 PII;`user_input` 截断 500 字 |
| Trace input/output | ✅ | 显式 set,非全量 args |
| Session ID | ✅ | Streamlit session 维度 |
| User ID | ✅ | 当前为 `$USER` 占位 |
| Tags | ✅ | `[survey-analysis, chat]` |
| Flush on exit | ✅ | `end_turn` 内调用 |

---

## 8. 常见坑(本项目踩过)

| 坑 | 现象 | 修复 |
| --- | --- | --- |
| `ALL_PROXY=socks://` | langfuse 内部 httpx 抛 `Unknown scheme for proxy URL` | `_init_langfuse` 临时弹出 `ALL_PROXY`/`all_proxy` 后再 init |
| `start_observation` ≠ current context | LLM GENERATION 起独立 trace,不嵌套 | 改用 `start_as_current_observation`(ExitStack 管理生命周期) |
| 直接传 `session_id` 给 `start_observation` | 不被识别 | 用 `propagate_attributes(session_id=...)` context manager |
| Langfuse v3 vs v4 API | v3 用 `trace()/span()`,v4 用 `start_observation` | 本项目锁定 v4(`langfuse>=4.0`) |
| OTel 提示 `No active span in current context` | 在生成器外调用 `get_trace_url()` | 只在 with 块内调用,或忽略(不影响数据上报) |

---

## 9. 验收 / 测试方法

### 9.1 单元冒烟(不需 LLM)

```bash
LANGFUSE_PUBLIC_KEY=... LANGFUSE_SECRET_KEY=... LANGFUSE_BASE_URL=https://cloud.langfuse.com \
python -c "
from app.observability import start_turn, end_turn, record_tool_call, record_tool_result
h = start_turn('probe', 'hi', session_id='probe-001', user_id='dev', tags=['probe'])
with record_tool_call(h, 'noop', {'x':1}) as s:
    record_tool_result(s, {'status':'ok','summary':'fake'})
end_turn(h, output={'rounds':1})
"
```

### 9.2 真实 LLM end-to-end

```bash
DEEPSEEK_API_KEY=... LANGFUSE_PUBLIC_KEY=... LANGFUSE_SECRET_KEY=... \
LANGFUSE_BASE_URL=https://cloud.langfuse.com python -c "
from app.agent import run_agent_turn
from app.state import AppState
state = AppState()
msgs = [{'role':'user','content':'你好'}]
for evt in run_agent_turn(msgs, state, session_id='e2e-001', user_id='dev'):
    pass
"
```

### 9.3 通过 API 反查 trace

```bash
curl -s -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" \
  "https://cloud.langfuse.com/api/public/traces?sessionId=e2e-001&limit=5" | jq .
```

期望返回:`name="survey-analysis.chat-turn"`,observations 内含 1 个 AGENT + ≥1 个 GENERATION,model=`deepseek-v4-pro`,tokens 完整。

---

## 10. 关闭可观测性

任选一种:
1. **临时**:启动前 `unset LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY` → 自动 no-op
2. **永久**:从 `.env` 删除两个 key → 同上
3. **彻底**:删除 `app/observability.py` 的调用点(不推荐,失去未来开关能力)

---

## 11. 相关文件

| 文件 | 作用 |
| --- | --- |
| `app/observability.py` | Langfuse 封装,零侵入降级 |
| `app/agent.py` | 在 `run_agent_turn` 接入 `start_turn`/`end_turn`/`record_tool_*` |
| `app/main.py` | 注入 `trace_session_id` + 调 `run_agent_turn` 时传 session/user |
| `.env.example` | LANGFUSE_* 环境变量样板 |
| `agent/skills/observability/langfuse/SKILL.md` | 官方 Agent Skill(供 Copilot CLI 检索) |
| `docs/agent-framework-research.md` | 框架对比调研,Langfuse 章节 419-468 |
