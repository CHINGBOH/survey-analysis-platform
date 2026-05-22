"""
app/agent.py — DeepSeek API (OpenAI-compatible) tool-use loop.
ReAct pattern: reason → call tool → observe → repeat until stop.
"""
import json
import os
from pathlib import Path
from typing import Any, Generator, cast

from openai import OpenAI

from app.hooks import (
    agent_stop,
    post_tool_use,
    post_tool_use_failure,
    pre_tool_use,
)
from app.router import filter_tools, route
from app.tools import (
    check_pipeline_status,
    get_results,
    get_variable_catalog,
    preview_data,
    read_log,
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
]


def _load_system_prompt() -> str:
    if SYSTEM_PROMPT_PATH.exists():
        return SYSTEM_PROMPT_PATH.read_text()
    return "你是问卷调查统计分析助手。"


def _dispatch(name: str, arguments: str, state) -> dict:
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
    """
    import httpx
    api_key = os.environ.get("DEEPSEEK_API_KEY", "")
    http_client = httpx.Client(transport=httpx.HTTPTransport())
    return OpenAI(api_key=api_key, base_url=DEEPSEEK_BASE_URL, http_client=http_client)


def run_agent_turn(
    api_messages: list, state
) -> Generator[dict, None, None]:
    """
    Generator — yields events during one conversational turn.
    Event types: "text" | "tool_call" | "tool_result"

    Mutates api_messages in-place (appends new assistant + tool turns).
    api_messages uses OpenAI message format throughout.
    """
    client = _make_client()
    base_system = _load_system_prompt()

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
                result = _dispatch(tc.function.name, tc.function.arguments, state)
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
