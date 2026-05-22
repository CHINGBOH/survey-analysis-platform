"""
app/agent.py — DeepSeek API (OpenAI-compatible) tool-use loop.
ReAct pattern: reason → call tool → observe → repeat until stop.
"""
import json
import os
from pathlib import Path
from typing import Any, Generator, Optional, cast

from openai import OpenAI

from app.hooks import (
    agent_stop,
    post_tool_use,
    post_tool_use_failure,
    pre_tool_use,
)
from app.observability import (
    end_turn,
    is_enabled as langfuse_enabled,
    record_tool_call,
    record_tool_result,
    start_turn,
    wrap_openai_client,
)
from app.router import filter_tools, route
from app.skill_loader import build_catalogue_block
from app.tools import (
    check_pipeline_status,
    dispatch_subagent,
    get_results,
    get_variable_catalog,
    interpret_results,
    preview_data,
    read_log,
    render_charts,
    run_analysis_module,
    run_clean,
    run_compile,
    run_report,
    run_selected_analysis,
    set_analysis_plan,
)

SYSTEM_PROMPT_PATH = Path(__file__).parent.parent / "agent" / "system_prompt.md"
DEEPSEEK_BASE_URL = "https://api.deepseek.com"
MODEL = "deepseek-v4-pro"
MAX_TOOL_ROUNDS = 20
MAX_TOKENS = 8192  # v4-pro uses reasoning tokens before content; needs extra budget

# ── Tool definitions (OpenAI function-calling format) ─────────────

TOOL_DEFS = [
    {
        "type": "function",
        "function": {
            "name": "set_analysis_plan",
            "description": "记录并确认分析计划。理解用户意图后调用：选哪些调查、跑哪些模块、是否对比、核心问题。Pydantic 会校验合法性。设置新计划会清空旧结果。在开始清洗/分析前必须先确认计划。",
            "parameters": {
                "type": "object",
                "properties": {
                    "surveys": {
                        "type": "array",
                        "items": {"type": "string", "enum": ["survey1", "survey2"]},
                        "description": "要分析的调查。单个=单组分析，两个=可对比",
                    },
                    "modules": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "要运行的模块列表，或 ['all'] 表示全部 12 个",
                    },
                    "compare": {
                        "type": "boolean",
                        "description": "是否对两个调查做对比分析（true 会自动包含两个调查）",
                    },
                    "focus": {
                        "type": "string",
                        "description": "核心研究问题（用户的自然语言诉求）",
                    },
                },
                "required": ["surveys", "modules"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "preview_data",
            "description": "预览数据文件的前N行，了解列结构和样本值。上传文件后应首先调用。",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {"type": "string", "description": "文件路径（相对项目根目录），留空使用已上传文件"},
                    "n_rows": {"type": "integer", "description": "预览行数，默认5"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_variable_catalog",
            "description": "从 SQLite variables 表获取变量目录（名称、标签、类型、测量级别）",
            "parameters": {
                "type": "object",
                "properties": {
                    "survey_id": {
                        "type": "string",
                        "enum": ["survey1", "survey2"],
                        "description": "调查编号",
                    }
                },
                "required": ["survey_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_clean",
            "description": "运行数据清洗管道：Excel → 编码 → SQLite 入库",
            "parameters": {
                "type": "object",
                "properties": {
                    "target": {
                        "type": "string",
                        "enum": ["survey1", "survey2", "all"],
                        "description": "清洗目标，默认 all",
                    }
                },
                "required": ["target"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_analysis_module",
            "description": "运行单个统计分析模块（Rscript 02-analyze/{module}.R）",
            "parameters": {
                "type": "object",
                "properties": {
                    "module": {
                        "type": "string",
                        "enum": [
                            "descriptives", "crosstabs", "ttest", "anova", "correlation",
                            "reliability", "factor_analysis", "regression",
                            "mediation", "moderation", "cluster", "power_bootstrap",
                        ],
                        "description": "模块名称",
                    }
                },
                "required": ["module"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_selected_analysis",
            "description": "按顺序批量运行多个分析模块",
            "parameters": {
                "type": "object",
                "properties": {
                    "modules": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "模块名称列表，如 ['reliability','factor_analysis','regression']",
                    }
                },
                "required": ["modules"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_compile",
            "description": "整合所有分析结果 .rds 文件，生成 compiled.rds",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_report",
            "description": "调用 Quarto 渲染 HTML 分析报告",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_results",
            "description": "读取某个已完成模块的真实计算结果(.rds→JSON)，用于向用户解读具体数值(如 α、KMO、R²、p值)。禁止凭空编造数字，要解读就先用此工具拿到真实值。",
            "parameters": {
                "type": "object",
                "properties": {
                    "module": {
                        "type": "string",
                        "enum": [
                            "descriptives", "crosstabs", "ttest", "anova", "correlation",
                            "reliability", "factor_analysis", "regression",
                            "mediation", "moderation", "cluster", "power_bootstrap",
                        ],
                        "description": "模块名称",
                    },
                    "survey_id": {
                        "type": "string",
                        "enum": ["survey1", "survey2"],
                        "description": "调查编号",
                    },
                },
                "required": ["module", "survey_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "check_pipeline_status",
            "description": "检查哪些分析模块已完成（.rds 文件存在），以及整合和报告状态",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_log",
            "description": "读取管道日志末尾，用于诊断失败原因",
            "parameters": {
                "type": "object",
                "properties": {
                    "n_lines": {"type": "integer", "description": "读取末尾行数，默认30"}
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "dispatch_subagent",
            "description": (
                "把专项任务委派给具备特定专长的子 agent(见系统提示「可调度 Subagent 角色」目录)。"
                "子 agent 不能执行工具,只产出文本建议; 主 agent 据此再决定后续动作。"
                "适用场景: 需要资深视角(如 data-scientist 看建模思路、prompt-engineer 改提示词)、"
                "或需要把复杂问题拆给独立角色独立思考时。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "role": {"type": "string", "description": "subagent 名称, 如 data-scientist / data-analyst / prompt-engineer"},
                    "task": {"type": "string", "description": "委派的具体任务"},
                    "context": {"type": "string", "description": "附加上下文(可选): 已有结果摘要、数据描述、约束条件"},
                },
                "required": ["role", "task"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "interpret_results",
            "description": (
                "读取已运行模块的 RDS,通过 instructor+Pydantic schema 约束生成结构化解读。"
                "每条 key_findings 强制带变量名 + 统计量名 + 数值,杜绝 LLM 编造数据。"
                "在分析模块完成后、生成报告前调用,把数字结果转成可信中文解读。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "module": {"type": "string", "description": "模块名,如 descriptives / ttest / regression"},
                    "survey_id": {"type": "string", "enum": ["survey1", "survey2"], "description": "默认 survey1"},
                },
                "required": ["module"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "render_charts",
            "description": (
                "把指定模块的 RDS 渲染为 PNG 图表包(ggplot2),输出到 output/charts/<module>_<sid>/。"
                "支持模块: descriptives(饼图/柱状/直方/Q-Q)、crosstabs(分组柱状)、correlation(热力图)、"
                "ttest(箱线图)、regression(系数森林图)。"
                "返回 manifest 含每张图的 file/title/type,可在 UI 预览或嵌入报告。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "module": {"type": "string", "description": "模块名"},
                    "survey_id": {"type": "string", "enum": ["survey1", "survey2"]},
                },
                "required": ["module"],
            },
        },
    },
]


def _load_system_prompt() -> str:
    base = (
        SYSTEM_PROMPT_PATH.read_text()
        if SYSTEM_PROMPT_PATH.exists()
        else "你是问卷调查统计分析助手。"
    )
    # 动态注入 skill / subagent 目录,让主 agent 知道可用的知识库和可委派的角色
    try:
        catalogue = build_catalogue_block()
    except Exception:
        catalogue = ""
    return base + ("\n" + catalogue if catalogue else "")


def _dispatch(name: str, arguments: str, state, trace=None) -> dict:
    """Parse JSON arguments and route to tool implementation."""
    try:
        inputs = json.loads(arguments) if arguments else {}
    except json.JSONDecodeError:
        inputs = {}

    fns = {
        "set_analysis_plan": lambda: set_analysis_plan(
            surveys=inputs["surveys"],
            modules=inputs["modules"],
            compare=inputs.get("compare", False),
            focus=inputs.get("focus", ""),
            state=state,
        ),
        "preview_data": lambda: preview_data(
            file_path=inputs.get("file_path"),
            n_rows=inputs.get("n_rows", 5),
            state=state,
        ),
        "get_variable_catalog": lambda: get_variable_catalog(
            survey_id=inputs.get("survey_id", "survey1")
        ),
        "run_clean": lambda: run_clean(
            target=inputs.get("target", "all"), state=state
        ),
        "run_analysis_module": lambda: run_analysis_module(
            module=inputs["module"], survey_id=inputs.get("survey_id"), state=state
        ),
        "run_selected_analysis": lambda: run_selected_analysis(
            modules=inputs["modules"], survey_id=inputs.get("survey_id"), state=state
        ),
        "get_results": lambda: get_results(
            module=inputs["module"], survey_id=inputs.get("survey_id", "survey1"), state=state
        ),
        "run_compile": lambda: run_compile(state=state),
        "run_report": lambda: run_report(state=state),
        "check_pipeline_status": lambda: check_pipeline_status(state=state),
        "read_log": lambda: read_log(n_lines=inputs.get("n_lines", 30)),
        "dispatch_subagent": lambda: dispatch_subagent(
            role=inputs["role"],
            task=inputs["task"],
            context=inputs.get("context", ""),
            state=state,
        ),
        "interpret_results": lambda: interpret_results(
            module=inputs["module"],
            survey_id=inputs.get("survey_id", "survey1"),
            state=state,
        ),
        "render_charts": lambda: render_charts(
            module=inputs["module"],
            survey_id=inputs.get("survey_id", "survey1"),
            state=state,
        ),
    }
    fn = fns.get(name)
    if fn is None:
        return {"status": "error", "summary": f"未知工具: {name}", "artifacts": {}, "next_actions": []}

    # PreToolUse hook — can BLOCK with an actionable reason fed back to the model
    gate = pre_tool_use(name, inputs, state)
    if not gate.allow:
        return {
            "status": "blocked",
            "summary": f"调用被拦截: {gate.reason}",
            "artifacts": {"blocked_tool": name},
            "next_actions": [gate.reason],
        }

    try:
        with record_tool_call(trace, name, inputs) as span:
            try:
                result = fn()
            except Exception as e:
                result = {"status": "error", "summary": f"工具 {name} 执行异常: {e}", "artifacts": {}, "next_actions": []}
            record_tool_result(span, result)
    except Exception:
        # Observability must never break the agent loop
        try:
            result = fn()
        except Exception as e:
            result = {"status": "error", "summary": f"工具 {name} 执行异常: {e}", "artifacts": {}, "next_actions": []}

    # PostToolUse hooks — record outcome
    post_tool_use(name, result, state)
    if result.get("status") == "error":
        post_tool_use_failure(name, result, state)
    return result


def _make_client() -> OpenAI:
    """Create OpenAI client pointed at DeepSeek.
    Explicit httpx.HTTPTransport bypasses ALL proxy env vars (ALL_PROXY
    uses socks:// which httpx cannot parse; HTTPS_PROXY through the local
    tunnel causes auth failures for deepseek-v4-pro).
    Direct HTTPS to api.deepseek.com is reachable without a proxy.

    If LANGFUSE_* env vars are set, the returned client is wrapped to
    automatically emit traces for every chat.completions call.
    """
    import httpx
    api_key = os.environ.get("DEEPSEEK_API_KEY", "")
    http_client = httpx.Client(transport=httpx.HTTPTransport())
    client = OpenAI(api_key=api_key, base_url=DEEPSEEK_BASE_URL, http_client=http_client)
    return wrap_openai_client(client)


def run_agent_turn(
    api_messages: list, state, *, session_id: Optional[str] = None, user_id: Optional[str] = None,
) -> Generator[dict, None, None]:
    """
    Generator — yields events during one conversational turn.
    Event types: "text" | "tool_call" | "tool_result"

    Mutates api_messages in-place (appends new assistant + tool turns).
    api_messages uses OpenAI message format throughout.

    session_id: Streamlit 会话 id,把同一对话多轮串到 Langfuse Sessions
    user_id: 当前操作者,Langfuse Users 视图聚合
    """
    client = _make_client()
    base_system = _load_system_prompt()

    # Open a Langfuse trace for the whole turn (no-op if not configured)
    last_user_msg = next(
        (m.get("content", "") for m in reversed(api_messages) if m.get("role") == "user"),
        "",
    )
    if isinstance(last_user_msg, list):
        # Multimodal content; flatten text parts for the trace label
        last_user_msg = " ".join(
            p.get("text", "") for p in last_user_msg if isinstance(p, dict)
        )
    turn_trace = start_turn(
        name="survey-analysis.chat-turn",
        user_input=str(last_user_msg)[:500],
        metadata={
            "model": MODEL,
            "phase": getattr(state, "phase", None),
            "n_messages": len(api_messages),
        },
        session_id=session_id,
        user_id=user_id,
        tags=["survey-analysis", "chat"],
    )

    # Router decides the phase + which tools to expose (re-evaluated each round
    # because tool calls change pipeline state, advancing the phase).
    def _route():
        decision = route(state)
        system = base_system + "\n\n---\n" + decision.hint
        tools = filter_tools(TOOL_DEFS, decision.allowed_tools)
        return system, tools, decision.phase

    # Build working messages: system first, then conversation
    def _build(msgs, system):
        return [{"role": "system", "content": system}] + msgs

    last_phase = None
    rounds_used = 0

    for _round in range(MAX_TOOL_ROUNDS):
        rounds_used += 1
        system, tools, phase = _route()
        if phase != last_phase:
            yield {"type": "phase", "phase": phase.value}
            last_phase = phase
        working = _build(list(api_messages), system)

        response = client.chat.completions.create(
            model=MODEL,
            messages=cast(Any, working),
            tools=tools,
            tool_choice="auto",
            max_tokens=MAX_TOKENS,
        )

        msg = response.choices[0].message
        finish = response.choices[0].finish_reason

        # v4-pro is a thinking model: actual reply is in content (after reasoning).
        # reasoning_content holds the chain-of-thought which we don't surface to users.
        text = msg.content or ""
        if text:
            yield {"type": "text", "content": text}

        # v4-pro thinking mode: reasoning_content MUST be echoed back on next turn
        reasoning = getattr(msg, "reasoning_content", None)

        if finish == "stop" or finish == "end_turn":
            asst_msg = {"role": "assistant", "content": msg.content or ""}
            if reasoning:
                asst_msg["reasoning_content"] = reasoning
            api_messages.append(asst_msg)
            break

        if finish == "tool_calls" and msg.tool_calls:
            # Filter to function-typed tool calls (SDK union includes Custom type with no .function).
            fn_calls = cast(list[Any], [tc for tc in msg.tool_calls if getattr(tc, "type", "function") == "function" and hasattr(tc, "function")])

            # Build assistant message with tool_calls (echo reasoning_content for v4-pro)
            asst_msg = {
                "role": "assistant",
                "content": msg.content or "",
                "tool_calls": [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {"name": tc.function.name, "arguments": tc.function.arguments},
                    }
                    for tc in fn_calls
                ],
            }
            if reasoning:
                asst_msg["reasoning_content"] = reasoning
            api_messages.append(asst_msg)

            # Execute each tool and collect results
            for tc in fn_calls:
                inputs_display = {}
                try:
                    inputs_display = json.loads(tc.function.arguments)
                except Exception:
                    pass

                yield {"type": "tool_call", "name": tc.function.name, "inputs": inputs_display}
                result = _dispatch(tc.function.name, tc.function.arguments, state, trace=turn_trace)
                yield {"type": "tool_result", "name": tc.function.name, "result": result}

                api_messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": json.dumps(result, ensure_ascii=False),
                })
            # Loop continues — next iteration re-routes (phase may have advanced)
        else:
            # Unexpected finish reason
            break

    agent_stop(rounds_used)
    end_turn(turn_trace, output={"rounds": rounds_used}, status="ok")
