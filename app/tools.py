"""
app/tools.py — Tool implementations for the analysis agent.
Each tool returns: {status, summary, next_actions, artifacts}
"""
import json
import sqlite3
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd
from pydantic import ValidationError

from app.requirements_schema import AnalysisPlan

ROOT = Path(__file__).resolve().parent.parent
LOG_FILE = ROOT / "logs" / "pipeline.log"
OUTPUT_RESULTS = ROOT / "output" / "results"
OUTPUT_REPORTS = ROOT / "output" / "reports"


def _log(msg: str):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"[{ts}] {msg}\n")


def _run(cmd: list[str], timeout: int = 300) -> tuple[int, str, str]:
    """Run a subprocess from project root, return (returncode, stdout, stderr)."""
    _log(f"RUN: {' '.join(cmd)}")
    result = subprocess.run(
        cmd, cwd=str(ROOT), capture_output=True, text=True, timeout=timeout
    )
    if result.stdout:
        _log("STDOUT: " + result.stdout[-2000:])
    if result.stderr:
        _log("STDERR: " + result.stderr[-2000:])
    return result.returncode, result.stdout, result.stderr


def _ok(summary: str, artifacts: Any = None, next_actions: Optional[list] = None) -> Dict:
    return {
        "status": "ok",
        "summary": summary,
        "artifacts": artifacts or {},
        "next_actions": next_actions or [],
    }


def _err(summary: str, detail: str = "") -> Dict:
    return {
        "status": "error",
        "summary": summary,
        "artifacts": {"detail": detail},
        "next_actions": ["read_log 查看详细错误"],
    }


PLAN_PATH = OUTPUT_RESULTS / "plan.json"


def load_plan() -> Optional[dict]:
    """Read the active analysis plan, if one has been set."""
    if PLAN_PATH.exists():
        try:
            return json.loads(PLAN_PATH.read_text())
        except Exception:
            return None
    return None


def survey_suffix(survey_id: str) -> str:
    return "s1" if survey_id == "survey1" else "s2"


def _resolve_surveys(survey_id: Optional[str] = None) -> List[str]:
    """Decide which surveys a tool should operate on.
    Priority: explicit survey_id override > active plan > both (default).
    """
    if survey_id and survey_id != "all":
        return [survey_id]
    plan = load_plan()
    if plan and plan.get("surveys"):
        return plan["surveys"]
    return ["survey1", "survey2"]


# ──────────────────────────────────────────────────────────────────
# Tool: set_analysis_plan — agent records its understanding of user intent
# ──────────────────────────────────────────────────────────────────

def set_analysis_plan(surveys, modules, compare=False, focus="", state=None) -> Dict:
    """Validate (Pydantic) and persist the agent's analysis plan.
    Validation here is the hallucination filter: bad survey/module names are
    rejected before any R script runs. Setting a new plan clears stale results.

    plan-review-gate: 计划通过 Pydantic 后,再走三维对抗式评审(Feasibility/
    Completeness/Scope),全部 PASS 才落盘; 任一 FAIL 返回 blocked,带具体 reasons
    给主 agent 自我纠正。可通过 PLAN_REVIEW_GATE=0 关闭。
    """
    try:
        plan = AnalysisPlan(surveys=surveys, modules=modules, compare=compare, focus=focus)
    except ValidationError as e:
        msgs = "; ".join(err.get("msg", str(err)) for err in e.errors())
        return _err(f"分析计划校验失败: {msgs}")

    # ── plan-review-gate ──────────────────────────────────────────
    from app.plan_review_gate import review_plan
    verdict = review_plan(
        {"surveys": plan.surveys, "modules": plan.modules, "compare": plan.compare, "focus": plan.focus},
    )
    if not verdict.passed:
        reasons = verdict.reasons() or ["评审未通过(未给出具体原因)"]
        return {
            "status": "blocked",
            "summary": "plan-review-gate 拦截: 计划未通过对抗式评审,请根据原因修改后重新提交。",
            "artifacts": {
                "feasibility": verdict.feasibility,
                "completeness": verdict.completeness,
                "scope": verdict.scope,
                "reasons": reasons,
            },
            "next_actions": reasons,
        }

    OUTPUT_RESULTS.mkdir(parents=True, exist_ok=True)
    # Fresh start — clear previous run's results so report reflects only this plan
    for f in OUTPUT_RESULTS.glob("*.rds"):
        f.unlink()

    manifest = plan.to_manifest()
    PLAN_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    if state is not None:
        state.plan = manifest

    mode = "对比模式" if plan.compare else "单组分析"
    return _ok(
        f"分析计划已确认（{mode}）: {plan.surveys} × {len(plan.modules)} 模块"
        + (f"，聚焦「{plan.focus}」" if plan.focus else ""),
        artifacts=manifest,
        next_actions=[
            f"run_clean 清洗 {plan.surveys}",
            "run_selected_analysis 按计划运行模块",
        ],
    )


# ──────────────────────────────────────────────────────────────────
# Tool: preview_data
# ──────────────────────────────────────────────────────────────────

def preview_data(file_path: Optional[str] = None, n_rows: int = 5, state=None) -> Dict:
    """Read first N rows of an Excel/CSV file.
    No auto-fallback: a data file must be explicitly selected/uploaded first.
    """
    if file_path:
        path = Path(file_path) if Path(file_path).is_absolute() else ROOT / file_path
    elif state and state.uploaded_path:
        path = Path(state.uploaded_path)
    else:
        return _err(
            "尚未选择数据文件。请提示用户在左侧「数据文件」面板选择现有文件或上传新文件，"
            "用户确认后才会进入分析流程（不自动使用任何文件）。"
        )

    if not path.exists():
        return _err(f"文件不存在: {path}")

    try:
        if path.suffix.lower() == ".csv":
            df = pd.read_csv(path, nrows=n_rows)
        else:
            df = pd.read_excel(path, nrows=n_rows)

        # Count total rows
        if path.suffix.lower() == ".csv":
            total = sum(1 for _ in open(path)) - 1
        else:
            df_full = pd.read_excel(path, nrows=0)
            total = pd.read_excel(path).shape[0]

        return _ok(
            f"已读取 {path.name}：共 {total} 行，{len(df.columns)} 列",
            artifacts={
                "file": str(path.name),
                "total_rows": total,
                "columns": list(df.columns),
                "dtypes": {c: str(t) for c, t in df.dtypes.items()},
                "preview": df.fillna("").to_dict(orient="records"),
            },
            next_actions=[
                "run_clean 将数据清洗入库 SQLite",
                "get_variable_catalog 获取变量目录（清洗后）",
            ],
        )
    except Exception as e:
        return _err(f"读取文件失败: {e}")


# ──────────────────────────────────────────────────────────────────
# Tool: get_variable_catalog
# ──────────────────────────────────────────────────────────────────

def get_variable_catalog(survey_id: str = "survey1") -> Dict:
    """Read variables table from SQLite."""
    db_path = ROOT / "data" / "db" / f"{survey_id}.db"
    if not db_path.exists():
        return _err(f"{survey_id}.db 不存在，请先运行 run_clean。")
    try:
        conn = sqlite3.connect(db_path)
        rows = conn.execute(
            "SELECT name, label_cn, type, category, spss_measure FROM variables WHERE survey=? ORDER BY category, name",
            (survey_id,),
        ).fetchall()
        conn.close()
        catalog = [
            {"name": r[0], "label": r[1], "type": r[2], "category": r[3], "measure": r[4]}
            for r in rows
        ]
        return _ok(
            f"{survey_id} 变量目录：共 {len(catalog)} 个变量",
            artifacts={"survey_id": survey_id, "variables": catalog},
            next_actions=["run_analysis_module 选择分析模块运行"],
        )
    except Exception as e:
        return _err(f"读取变量目录失败: {e}")


# ──────────────────────────────────────────────────────────────────
# Tool: run_clean
# ──────────────────────────────────────────────────────────────────

def run_clean(target: str = "all", state=None) -> Dict:
    """Run clean_to_sqlite.py to import Excel → SQLite.
    If target is the default and a plan exists, clean only the plan's surveys.
    """
    if target == "all":
        plan_surveys = _resolve_surveys()
        if len(plan_surveys) == 1:
            target = plan_surveys[0]
    if state:
        state.stage = "cleaning"
    rc, stdout, stderr = _run(["python3", "01-clean/clean_to_sqlite.py", target])
    if rc != 0:
        return _err(f"清洗失败 (exit {rc}): {stderr[-500:]}", detail=stderr)
    if state:
        state.clean_done = True
        state.stage = "uploaded"
    lines = [l for l in stdout.splitlines() if l.strip()]
    summary = "\n".join(lines[-6:]) if lines else "完成"
    return _ok(
        f"数据清洗完成（{target}）: {summary}",
        artifacts={"target": target, "output": stdout[-1000:]},
        next_actions=[
            "get_variable_catalog 查看变量目录",
            "check_pipeline_status 检查管道状态",
            "run_selected_analysis 运行分析模块",
        ],
    )


# ──────────────────────────────────────────────────────────────────
# Tool: run_analysis_module
# ──────────────────────────────────────────────────────────────────

VALID_MODULES = [
    "descriptives", "crosstabs", "ttest", "anova", "correlation",
    "reliability", "factor_analysis", "regression",
    "mediation", "moderation", "cluster", "power_bootstrap",
]


def run_analysis_module(module: str, survey_id: Optional[str] = None, state=None) -> Dict:
    """Run a single Rscript analysis module on the resolved survey scope."""
    if module not in VALID_MODULES:
        return _err(f"未知模块: {module}，可用模块: {VALID_MODULES}")

    script = ROOT / "02-analyze" / f"{module}.R"
    if not script.exists():
        return _err(f"脚本不存在: 02-analyze/{module}.R")

    if state:
        state.set_module(module, "running")

    surveys = _resolve_surveys(survey_id)
    _log(f"分析模块: {module} (surveys={surveys})")
    rc, stdout, stderr = _run(["Rscript", f"02-analyze/{module}.R", *surveys], timeout=120)

    if rc != 0:
        if state:
            state.set_module(module, "error")
        return _err(f"{module} 失败 (exit {rc})", detail=stderr[-800:])

    if state:
        state.set_module(module, "done")

    # Check that output .rds files were created (only for surveys we ran)
    rds_files = [f"output/results/{module}_{survey_suffix(s)}.rds" for s in surveys]
    created = [f for f in rds_files if (ROOT / f).exists()]
    summary_lines = [l for l in stdout.splitlines() if l.strip()]
    short_out = "\n".join(summary_lines[-5:]) if summary_lines else "完成"

    return _ok(
        f"{module} 分析完成 — {short_out}",
        artifacts={
            "module": module,
            "rds_created": created,
            "output_tail": stdout[-600:],
        },
        next_actions=[
            "check_pipeline_status 查看整体进度",
            "run_compile 所有模块完成后整合结果",
        ],
    )


# ──────────────────────────────────────────────────────────────────
# Tool: run_selected_analysis
# ──────────────────────────────────────────────────────────────────

def run_selected_analysis(modules: list, survey_id: Optional[str] = None, state=None) -> Dict:
    """Run multiple analysis modules in sequence on the resolved survey scope."""
    invalid = [m for m in modules if m not in VALID_MODULES]
    if invalid:
        return _err(f"未知模块: {invalid}")

    surveys = _resolve_surveys(survey_id)
    results = {}
    failed = []
    for mod in modules:
        r = run_analysis_module(mod, survey_id=survey_id, state=state)
        results[mod] = r["status"]
        if r["status"] == "error":
            failed.append(mod)

    done = [m for m in modules if results[m] == "ok"]
    summary = f"完成 {len(done)}/{len(modules)} 个模块 (surveys={surveys})"
    if failed:
        summary += f"，失败: {failed}"

    return _ok(
        summary,
        artifacts={"results": results, "failed": failed, "surveys": surveys},
        next_actions=["run_compile 整合结果" if not failed else "read_log 查看失败日志"],
    )


# ──────────────────────────────────────────────────────────────────
# Tool: get_results — read computed statistics from a module's .rds
# ──────────────────────────────────────────────────────────────────

def get_results(module: str, survey_id: str = "survey1", state=None) -> Dict:
    """Read the actual computed numbers from a module result (.rds → JSON).
    This lets the agent interpret REAL values instead of hallucinating them.
    """
    if module not in VALID_MODULES:
        return _err(f"未知模块: {module}")
    suffix = survey_suffix(survey_id)
    path = OUTPUT_RESULTS / f"{module}_{suffix}.rds"
    if not path.exists():
        return _err(f"{module}_{suffix}.rds 不存在，请先运行该模块（{survey_id}）")

    rc, stdout, stderr = _run(["Rscript", "03-integrate/read_result.R", str(path)], timeout=60)
    if rc != 0:
        return _err(f"读取 {module} 结果失败", detail=stderr[-400:])
    try:
        data = json.loads(stdout)
    except json.JSONDecodeError:
        return _err(f"{module} 结果 JSON 解析失败", detail=stdout[:400])

    return _ok(
        f"{module}（{survey_id}）的计算结果",
        artifacts={"module": module, "survey": survey_id, "results": data},
        next_actions=["结合这些真实数值给用户解读，标注显著性"],
    )


# ──────────────────────────────────────────────────────────────────
# Tool: run_compile
# ──────────────────────────────────────────────────────────────────

def run_compile(state=None) -> Dict:
    """Run compile.R to merge all .rds files into compiled.rds."""
    OUTPUT_RESULTS.mkdir(parents=True, exist_ok=True)
    if state:
        state.stage = "compiling"
    rc, stdout, stderr = _run(["Rscript", "03-integrate/compile.R"])
    if rc != 0:
        return _err(f"整合失败 (exit {rc})", detail=stderr[-500:])
    compiled = OUTPUT_RESULTS / "compiled.rds"
    if not compiled.exists():
        return _err("compiled.rds 未生成，请检查日志")
    if state:
        state.stage = "uploaded"
    lines = [l for l in stdout.splitlines() if l.strip()]
    return _ok(
        f"结果整合完成: {lines[-1] if lines else 'compiled.rds'}",
        artifacts={"compiled_rds": str(compiled)},
        next_actions=["run_report 生成 Quarto HTML 报告"],
    )


# ──────────────────────────────────────────────────────────────────
# Tool: run_report
# ──────────────────────────────────────────────────────────────────

def run_report(state=None) -> Dict:
    """Render Quarto HTML report."""
    compiled = OUTPUT_RESULTS / "compiled.rds"
    if not compiled.exists():
        return _err("compiled.rds 不存在，请先运行 run_compile。")

    OUTPUT_REPORTS.mkdir(parents=True, exist_ok=True)
    if state:
        state.stage = "reporting"

    rc, stdout, stderr = _run(
        ["quarto", "render", "04-report/report.qmd", "--to", "html"],
        timeout=180,
    )
    if rc != 0:
        return _err(f"报告生成失败 (exit {rc})", detail=(stdout + stderr)[-800:])

    # Quarto renders to 04-report/report.html by default
    report_html = ROOT / "04-report" / "report.html"
    if report_html.exists():
        if state:
            state.report_path = str(report_html)
            state.stage = "done"
        return _ok(
            "HTML 报告生成成功",
            artifacts={"report_html": str(report_html)},
            next_actions=["在右侧「查看报告」标签页中打开报告"],
        )
    return _err("Quarto 运行完成但 report.html 未找到", detail=stdout[-400:])


# ──────────────────────────────────────────────────────────────────
# Tool: check_pipeline_status
# ──────────────────────────────────────────────────────────────────

def check_pipeline_status(state=None) -> Dict:
    """Check module completion **relative to the active plan**.
    A module is 'done' when every PLANNED survey has its .rds — a survey1-only
    plan does not require survey2 results.
    """
    plan = load_plan()
    if plan:
        plan_surveys = plan.get("surveys", ["survey1", "survey2"])
        plan_modules = plan.get("modules", VALID_MODULES)
    else:
        plan_surveys = ["survey1", "survey2"]
        plan_modules = VALID_MODULES

    suffixes = [survey_suffix(s) for s in plan_surveys]

    statuses = {}
    for mod in plan_modules:
        present = [suf for suf in suffixes if (OUTPUT_RESULTS / f"{mod}_{suf}.rds").exists()]
        if len(present) == len(suffixes):
            statuses[mod] = "done"
        elif present:
            statuses[mod] = "partial"
        else:
            statuses[mod] = "missing"

    compiled = (OUTPUT_RESULTS / "compiled.rds").exists()
    report = (ROOT / "04-report" / "report.html").exists()
    done_count = sum(1 for s in statuses.values() if s == "done")

    # Sync state if provided
    if state:
        for mod, s in statuses.items():
            if s == "done":
                state.set_module(mod, "done")
        if compiled and report:
            state.stage = "done"
            state.report_path = str(ROOT / "04-report" / "report.html")

    scope = "+".join(plan_surveys)
    return _ok(
        f"管道状态：{done_count}/{len(plan_modules)} 模块完成（计划范围 {scope}）| 整合: {'✓' if compiled else '✗'} | 报告: {'✓' if report else '✗'}",
        artifacts={
            "modules": statuses,
            "surveys": plan_surveys,
            "compiled_rds": compiled,
            "report_html": report,
        },
        next_actions=_suggest_next(statuses, compiled, report),
    )


def _suggest_next(statuses: dict, compiled: bool, report: bool) -> list:
    missing = [m for m, s in statuses.items() if s == "missing"]
    if missing:
        return [f"run_selected_analysis 运行缺失模块: {missing[:4]}..."]
    if not compiled:
        return ["run_compile 整合结果"]
    if not report:
        return ["run_report 生成报告"]
    return ["分析管道已完成，可在「查看报告」标签查看结果"]


# ──────────────────────────────────────────────────────────────────
# Tool: read_log
# ──────────────────────────────────────────────────────────────────

def read_log(n_lines: int = 30) -> Dict:
    """Read last N lines of pipeline.log."""
    if not LOG_FILE.exists():
        return _ok("日志文件不存在（管道尚未运行）", artifacts={"log": ""})
    lines = LOG_FILE.read_text().splitlines()
    tail = "\n".join(lines[-n_lines:])
    return _ok(
        f"日志末尾 {min(n_lines, len(lines))} 行",
        artifacts={"log": tail, "total_lines": len(lines)},
    )


# ──────────────────────────────────────────────────────────────────
# Tool: dispatch_subagent — 把专项任务委派给具备特定专长的子 agent
# ──────────────────────────────────────────────────────────────────

def dispatch_subagent(role: str, task: str, context: str = "", state=None) -> Dict:
    """以 role 对应的 subagent 系统提示运行一次性 LLM 调用,产出该任务的专业建议。

    role: 必须是 agent/subagents/<role>.md 中存在的角色 (如 data-scientist)
    task: 要委派的具体任务自然语言描述
    context: 可选附加上下文(数据片段、已得结果摘要等)

    返回 artifacts.response 中是子 agent 的完整回答。
    注意: 子 agent 不能调用本系统的工具 — 只产出分析/建议文本,主 agent 再据此行动。
    """
    from app.skill_loader import load_subagent_content, load_subagents

    content = load_subagent_content(role)
    if content is None:
        available = [sa.name for sa in load_subagents()]
        return _err(f"未知 subagent 角色: {role}。可用: {available}")

    # 剥掉 frontmatter,只用正文做 system prompt
    import re as _re
    body = _re.sub(r"^---\s*\n.*?\n---\s*\n", "", content, count=1, flags=_re.DOTALL).strip()
    system = body + "\n\n注意: 你是被主 agent 委派的咨询者,只产出文本建议,不能调用工具。"

    user_msg = f"## 任务\n{task}"
    if context:
        user_msg += f"\n\n## 上下文\n{context}"

    try:
        # 延迟导入避免循环
        from app.agent import _make_client
        import os as _os
        client = _make_client()
        resp = client.chat.completions.create(
            model=_os.environ.get("SUBAGENT_MODEL", "deepseek-v4-pro"),
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_msg},
            ],
            max_tokens=2000,
            temperature=0.3,
        )
        text = (resp.choices[0].message.content or "").strip()
        usage = getattr(resp, "usage", None)
        usage_dict = {
            "prompt_tokens": getattr(usage, "prompt_tokens", None),
            "completion_tokens": getattr(usage, "completion_tokens", None),
        } if usage else {}
    except Exception as e:
        return _err(f"子 agent 调用失败: {e}")

    return _ok(
        f"子 agent 「{role}」 已产出建议 ({len(text)} 字)",
        artifacts={"role": role, "task": task[:200], "response": text, "usage": usage_dict},
        next_actions=["参考 response,决定后续工具调用或回答用户"],
    )


# ──────────────────────────────────────────────────────────────────
# Tool: interpret_results — 用 instructor+Pydantic 约束的结构化解读
# 防数据编造的核心: schema 强制每条 finding 引用具体数值
# ──────────────────────────────────────────────────────────────────

def _survey_suffix_local(s: str) -> str:
    return "s1" if s == "survey1" else ("s2" if s == "survey2" else s)


def interpret_results(module: str, survey_id: str = "survey1", state=None) -> Dict:
    """读取 module 的 RDS,转 JSON 投给 LLM,在 ModuleInterpretation schema 约束下生成解读。

    保证:每条 key_findings 必有 variable + statistic_name + value(来自真实 RDS)。
    LLM 若编造,instructor 会重试; 重试仍失败返回 error。
    """
    if module not in VALID_MODULES:
        return _err(f"未知模块: {module}")

    rds_path = OUTPUT_RESULTS / f"{module}_{_survey_suffix_local(survey_id)}.rds"
    if not rds_path.exists():
        return _err(f"RDS 不存在: {rds_path.relative_to(ROOT)}; 请先运行该模块")

    # 1) RDS → JSON
    rc, stdout, stderr = _run(
        ["Rscript", "02-analyze/rds_to_json.R", str(rds_path.relative_to(ROOT)), "30"],
        timeout=30,
    )
    if rc != 0:
        return _err(f"RDS 转 JSON 失败 (exit {rc})", detail=stderr[-400:])

    raw_json = stdout.strip()
    # 截断超长上下文(保留前 30000 字符,够 LLM 看)
    if len(raw_json) > 30000:
        raw_json = raw_json[:30000] + "\n...[truncated]"

    # 2) 结构化解读
    from app.structured import ModuleInterpretation, structured_chat
    system = (
        "你是问卷统计分析师。给定一个分析模块的 JSON 结果,产出 ModuleInterpretation。\n"
        "硬约束:\n"
        "1. 每条 key_findings 的 value 必须从输入 JSON 中直接取得,不允许编造或四舍五入到不存在的位数\n"
        "2. variable 必须是 JSON 中真实出现的字段名/变量名\n"
        "3. interpretation 必须引用该 value(中文表述)\n"
        "4. 不显著的发现不要标 significant=True\n"
        "5. 3-6 条最关键的发现即可,不要堆砌\n"
    )
    user = (
        f"## 模块\n{module}\n\n"
        f"## 调查\n{survey_id}\n\n"
        f"## 原始统计结果(JSON)\n```json\n{raw_json}\n```\n"
    )

    result = structured_chat(ModuleInterpretation, system=system, user=user, temperature=0.1, max_retries=2)
    if result is None:
        return _err("结构化解读失败(instructor 多次重试仍未通过校验)")

    payload = result.model_dump()
    return _ok(
        f"{module}@{survey_id} 已生成结构化解读,{len(payload['key_findings'])} 条关键发现",
        artifacts={"interpretation": payload, "rds": str(rds_path.relative_to(ROOT))},
        next_actions=[
            "可将 interpretation 嵌入报告章节",
            "调用 dispatch_subagent 让 data-scientist 复核解读",
        ],
    )
