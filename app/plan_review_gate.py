"""
app/plan_review_gate.py — set_analysis_plan 的对抗式评审闸门。

参考 agent/skills/workflow/plan-review-gate/SKILL.md:
- 三个独立维度评审: Feasibility / Completeness / Scope
- 全部 PASS 才放行,任一 FAIL 退回 reasons 给主 agent 自我纠正
- 单次 LLM 调用产出三段结构化判断(节省 token / 延迟)

启用方式: 默认开。设置 PLAN_REVIEW_GATE=0 关闭。
失败时 set_analysis_plan 返回 status=blocked + reasons,主 agent 应据此重新规划再 call。
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parent.parent
KNOWN_MODULES = [
    "descriptives", "crosstabs", "ttest", "anova", "correlation",
    "reliability", "factor_analysis", "regression", "mediation",
    "moderation", "cluster", "power_bootstrap", "survey_specific",
]
KNOWN_SURVEYS = ["survey1", "survey2"]


@dataclass
class ReviewVerdict:
    passed: bool
    feasibility: str
    completeness: str
    scope: str

    def reasons(self) -> List[str]:
        out = []
        for label, v in (
            ("可行性", self.feasibility),
            ("完整性", self.completeness),
            ("范围对齐", self.scope),
        ):
            if v.upper().startswith("FAIL"):
                out.append(f"[{label}] {v[5:].lstrip(' :：-')}")
        return out


def _enabled() -> bool:
    return os.environ.get("PLAN_REVIEW_GATE", "1") != "0"


def _static_checks(surveys, modules, focus) -> List[str]:
    """免 LLM 的硬规则,优先拦截 LLM 也判断不出的事实错误。"""
    errs: List[str] = []
    bad_surveys = [s for s in surveys if s not in KNOWN_SURVEYS]
    if bad_surveys:
        errs.append(f"survey 名称非法: {bad_surveys}, 仅支持 {KNOWN_SURVEYS}")
    flat_modules = modules
    if flat_modules and flat_modules != ["all"]:
        bad = [m for m in flat_modules if m not in KNOWN_MODULES]
        if bad:
            errs.append(f"module 名称非法: {bad}, 合法模块见系统提示")
    if not surveys:
        errs.append("surveys 为空")
    if not modules:
        errs.append("modules 为空")
    return errs


_REVIEWER_SYSTEM = """你是一名严苛的分析计划评审员,以三个独立视角审查问卷分析计划。

维度定义:
1. Feasibility(可行性): 计划中的 survey/module 在系统里是否真实存在; 模块依赖顺序是否合理(如 mediation 隐含需要 regression 基础); compare=True 时是否包含 ≥2 个 survey。
2. Completeness(完整性): focus(研究问题)是否被 modules 充分覆盖? 例如 focus 提到"信度"但 modules 没有 reliability 即 FAIL; focus 提到"组间差异"但没有 ttest/anova 即 FAIL。
3. Scope(范围对齐): 是否过度膨胀(无关模块大量纳入)或过度收缩(明显遗漏); 与用户原意是否匹配。

按 PlanReviewResult schema 输出。每维 passed=False 时,reason 必须给出可执行的修正建议。"""


def _llm_review(plan: dict, client=None) -> ReviewVerdict:
    """instructor + Pydantic 强制结构化评审。失败时降级为放行(并在 verdict 中标注)。"""
    from app.structured import PlanReviewResult, structured_chat

    user_msg = (
        "请评审以下分析计划:\n"
        f"```json\n{json.dumps(plan, ensure_ascii=False, indent=2)}\n```\n"
        f"合法 surveys: {KNOWN_SURVEYS}\n"
        f"合法 modules: {KNOWN_MODULES}\n"
    )

    result = structured_chat(
        PlanReviewResult,
        system=_REVIEWER_SYSTEM,
        user=user_msg,
        temperature=0.0,
    )

    if result is None:
        return ReviewVerdict(
            True,
            "PASS (review skipped: structured call failed)",
            "PASS (review skipped)",
            "PASS (review skipped)",
        )

    def _fmt(v) -> str:
        return ("PASS " if v.passed else "FAIL ") + v.reason

    return ReviewVerdict(
        passed=result.overall_passed,
        feasibility=_fmt(result.feasibility),
        completeness=_fmt(result.completeness),
        scope=_fmt(result.scope),
    )


def review_plan(plan: dict, client=None) -> ReviewVerdict:
    """评审一个 plan dict。返回 ReviewVerdict; 若 PLAN_REVIEW_GATE=0 永远 PASS。

    plan: {"surveys": [...], "modules": [...], "compare": bool, "focus": str}
    client: 可选 OpenAI 兼容客户端,缺省则惰性创建(避免循环依赖)。
    """
    if not _enabled():
        return ReviewVerdict(True, "PASS (gate disabled)", "PASS (gate disabled)", "PASS (gate disabled)")

    static_errs = _static_checks(plan.get("surveys", []), plan.get("modules", []), plan.get("focus", ""))
    if static_errs:
        return ReviewVerdict(
            False,
            "FAIL " + "; ".join(static_errs),
            "PASS",
            "PASS",
        )

    if client is None:
        from app.agent import _make_client  # 延迟导入,避免循环
        client = _make_client()

    return _llm_review(plan)
