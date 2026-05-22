"""
app/hooks.py — Lifecycle hooks for the analysis agent.

In-process port of the Claude Code hook system (claude-code-hooks-mastery):
- pre_tool_use:  validate prerequisites BEFORE a tool runs; can BLOCK (like exit 2)
- post_tool_use: record result + sync state AFTER a tool runs
- user_prompt_submit / agent_stop: session bookkeeping

All events are appended to logs/events.jsonl for observability
(claude-code-hooks-multi-agent-observability pattern).
"""
import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EVENTS_LOG = ROOT / "logs" / "events.jsonl"
OUTPUT_RESULTS = ROOT / "output" / "results"


@dataclass
class HookResult:
    allow: bool
    reason: str = ""


def log_event(event_type: str, payload: dict):
    """Append a structured event to logs/events.jsonl."""
    EVENTS_LOG.parent.mkdir(parents=True, exist_ok=True)
    record = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "event": event_type,
        **payload,
    }
    with open(EVENTS_LOG, "a") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


# ──────────────────────────────────────────────────────────────────
# PreToolUse — validate prerequisites, can BLOCK
# ──────────────────────────────────────────────────────────────────

# Tools that need clean data in SQLite before they can run
_NEEDS_CLEAN = {
    "get_variable_catalog", "run_analysis_module", "run_selected_analysis",
}
# Tools that need at least one analysis result before they can run
_NEEDS_ANALYSIS = {"run_compile"}
# Tools that need compiled.rds before they can run
_NEEDS_COMPILE = {"run_report"}


def _db_exists() -> bool:
    return (ROOT / "data" / "db" / "survey1.db").exists()


def _any_results() -> bool:
    return OUTPUT_RESULTS.exists() and any(OUTPUT_RESULTS.glob("*_s*.rds"))


def _compiled_exists() -> bool:
    return (OUTPUT_RESULTS / "compiled.rds").exists()


def pre_tool_use(name: str, inputs: dict, state=None) -> HookResult:
    """Gate a tool call. Returns HookResult(allow=False, reason=...) to block.
    Mirrors Claude Code pre_tool_use exit-code-2 blocking with a clear reason
    that gets fed back to the model so it can self-correct.
    """
    log_event("pre_tool_use", {"tool": name, "inputs": inputs})

    # Prerequisite gates — block with an actionable reason
    if name in _NEEDS_CLEAN and not _db_exists():
        return HookResult(False, "数据库不存在，必须先调用 run_clean 完成清洗入库。")

    if name in _NEEDS_ANALYSIS and not _any_results():
        return HookResult(False, "尚无任何分析结果，必须先运行分析模块再 run_compile。")

    if name in _NEEDS_COMPILE and not _compiled_exists():
        return HookResult(False, "compiled.rds 不存在，必须先 run_compile 再 run_report。")

    return HookResult(True)


# ──────────────────────────────────────────────────────────────────
# PostToolUse — record result, sync state
# ──────────────────────────────────────────────────────────────────

def post_tool_use(name: str, result: dict, state=None):
    """Record a completed tool call and its status."""
    log_event("post_tool_use", {
        "tool": name,
        "status": result.get("status"),
        "summary": result.get("summary", "")[:200],
    })


def post_tool_use_failure(name: str, result: dict, state=None):
    """Record a failed tool call separately for quick triage."""
    log_event("post_tool_use_failure", {
        "tool": name,
        "summary": result.get("summary", ""),
        "detail": str(result.get("artifacts", {}).get("detail", ""))[:500],
    })


# ──────────────────────────────────────────────────────────────────
# Session events
# ──────────────────────────────────────────────────────────────────

def user_prompt_submit(prompt: str):
    log_event("user_prompt_submit", {"prompt": prompt[:300]})


def agent_stop(rounds: int):
    log_event("agent_stop", {"rounds": rounds})
