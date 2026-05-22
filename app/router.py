"""
app/router.py — Phase-based router (Hub-and-Spoke).

Claude Code routes between permission modes / skills / subagents based on
context. This router does the equivalent for the survey agent: it reads the
pipeline state, decides the current PHASE, and narrows the exposed tool set
to that phase (+ universal diagnostics). Narrowing the action space is the
ECC harness principle "load tools on demand" — fewer choices → less drift.

The router is SOFT (it hides irrelevant tools and injects a hint); the HARD
prerequisite enforcement lives in hooks.pre_tool_use.
"""
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_RESULTS = ROOT / "output" / "results"


class Phase(str, Enum):
    EXPLORE = "explore"   # understand the raw data
    CLEAN = "clean"       # Excel → SQLite
    ANALYZE = "analyze"   # run statistical modules
    REPORT = "report"     # compile + render
    DONE = "done"         # report ready, answer follow-ups


# Always available regardless of phase — diagnostics + result reading + 协作
_UNIVERSAL = {"read_log", "check_pipeline_status", "get_results", "dispatch_subagent",
              "interpret_results", "render_charts",
              "list_report_templates", "generate_word", "generate_pdf", "export_charts_bundle"}

# Tools exposed per phase (union with _UNIVERSAL).
# set_analysis_plan is available in early phases so the agent can (re)confirm intent.
_PHASE_TOOLS = {
    Phase.EXPLORE: {"preview_data", "get_variable_catalog", "set_analysis_plan", "run_clean"},
    Phase.CLEAN:   {"set_analysis_plan", "run_clean", "preview_data", "get_variable_catalog"},
    Phase.ANALYZE: {"set_analysis_plan", "run_analysis_module", "run_selected_analysis",
                    "get_variable_catalog", "preview_data"},
    Phase.REPORT:  {"run_compile", "run_report"},
    Phase.DONE:    {"set_analysis_plan", "preview_data", "get_variable_catalog",
                    "run_selected_analysis", "run_compile", "run_report"},
}

_PHASE_HINTS = {
    Phase.EXPLORE: "当前阶段：探索。**用户尚未选择数据文件**——请先提示用户在左侧面板选择现有文件或上传，不要自行假设或调用 preview_data 抓取文件。用户确认数据后再 preview_data，并询问分析意图(哪个调查/哪些模块/核心问题)，意图清楚后 set_analysis_plan。",
    Phase.CLEAN:   "当前阶段：清洗。若尚未确认分析计划，先 set_analysis_plan；然后 run_clean（会按计划只清洗所选调查）。",
    Phase.ANALYZE: "当前阶段：分析。按已确认计划用 run_selected_analysis 运行模块（自动只跑计划内的调查）。若用户改主意，可重新 set_analysis_plan。",
    Phase.REPORT:  "当前阶段：报告。先 run_compile（按计划编译），再 run_report 渲染动态 HTML。",
    Phase.DONE:    "当前阶段：已完成。报告已生成。可回答追问、补跑模块、切换调查或重新规划。",
}


@dataclass
class RouteDecision:
    phase: Phase
    allowed_tools: set
    hint: str


def _db_exists() -> bool:
    return (ROOT / "data" / "db" / "survey1.db").exists()


def _module_count() -> int:
    if not OUTPUT_RESULTS.exists():
        return 0
    mods = {p.stem.rsplit("_s", 1)[0] for p in OUTPUT_RESULTS.glob("*_s*.rds")}
    return len(mods)


def _compiled_exists() -> bool:
    return (OUTPUT_RESULTS / "compiled.rds").exists()


def _report_exists() -> bool:
    return (ROOT / "04-report" / "report.html").exists()


def determine_phase(state=None) -> Phase:
    """Infer the pipeline phase. Gated on EXPLICIT data selection: until the user
    selects a data source in this session, stay in EXPLORE — leftover DB/results
    on disk do NOT auto-resume the pipeline. After selection, derive the phase
    from filesystem progress (ground truth, not LLM claims).
    """
    has_selection = state is not None and getattr(state, "uploaded_path", None)
    if not has_selection:
        return Phase.EXPLORE

    if _report_exists() and _compiled_exists():
        return Phase.DONE
    if _module_count() >= 1 and not _report_exists():
        if _compiled_exists() or _module_count() >= 6:
            return Phase.REPORT
        return Phase.ANALYZE
    if _db_exists():
        return Phase.ANALYZE
    return Phase.CLEAN


def route(state=None) -> RouteDecision:
    """Pick the active phase and the tool set to expose."""
    phase = determine_phase(state)
    allowed = set(_PHASE_TOOLS[phase]) | _UNIVERSAL
    return RouteDecision(phase=phase, allowed_tools=allowed, hint=_PHASE_HINTS[phase])


def filter_tools(tool_defs: list, allowed: set) -> list:
    """Return only the OpenAI tool defs whose function name is in `allowed`."""
    return [t for t in tool_defs if t["function"]["name"] in allowed]
