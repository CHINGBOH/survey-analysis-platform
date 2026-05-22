"""
app/structured.py — instructor + Pydantic 约束 LLM 输出。

对应 system_prompt 里"禁止编造任何统计数值"的硬约束:
用 schema 把 LLM 关键输出节点的形状钉死,避免:
- plan-review-gate 评审结论被 LLM 用自然语言搪塞
- 数据解读环节凭空生成统计数字
- 报告章节"显著性"判断没有 p 值出处

设计原则:
- 所有 schema 中,凡是统计量(p/F/r/d/β/...)字段必须 Optional + 描述要求"必须来自输入数据,不能编造"
- 解读字段强制引用具体变量名 + 数值
- 失败时 instructor 自动重试至 max_retries
"""
from __future__ import annotations

import os
from typing import Any, List, Literal, Optional, Type, TypeVar

import instructor
from pydantic import BaseModel, Field

T = TypeVar("T", bound=BaseModel)


# ──────────────────────────────────────────────────────────────────
# Plan-Review-Gate schemas
# ──────────────────────────────────────────────────────────────────

class DimensionVerdict(BaseModel):
    """单个维度的评审结论。"""
    passed: bool = Field(..., description="True=该维度通过, False=拒绝")
    reason: str = Field(
        ...,
        description="若 passed=False,必须给出可执行的具体修正建议(<=80 字); passed=True 时简述判断依据",
        max_length=200,
    )


class PlanReviewResult(BaseModel):
    """plan-review-gate 完整三维评审。"""
    feasibility: DimensionVerdict = Field(..., description="可行性:survey/module 是否真实存在 + 依赖顺序")
    completeness: DimensionVerdict = Field(..., description="完整性:focus 是否被 modules 覆盖")
    scope: DimensionVerdict = Field(..., description="范围对齐:是否过度膨胀或过度收缩")

    @property
    def overall_passed(self) -> bool:
        return all(v.passed for v in (self.feasibility, self.completeness, self.scope))


# ──────────────────────────────────────────────────────────────────
# 模块解读 schemas — 防数据编造的核心
# ──────────────────────────────────────────────────────────────────

class StatFinding(BaseModel):
    """一条带数值证据的统计发现。"""
    variable: str = Field(..., description="涉及的变量名(必须来自输入数据)")
    statistic_name: str = Field(..., description="统计量名,如 mean / sd / p_value / r / cohen_d / F / chi2")
    value: float = Field(..., description="统计量数值,必须来自工具返回的真实结果,不允许编造")
    significant: Optional[bool] = Field(None, description="是否显著(p<0.05);若不适用置 None")
    interpretation: str = Field(..., description="该发现的中文解读(<=80 字),必须引用上面的数值", max_length=200)


class ModuleInterpretation(BaseModel):
    """一次分析模块输出的结构化解读。"""
    module: str = Field(..., description="模块名,如 descriptives / ttest / regression")
    survey_id: str = Field(..., description="survey1 或 survey2")
    n_total: Optional[int] = Field(None, description="样本量(来自输入)")
    key_findings: List[StatFinding] = Field(
        default_factory=list,
        description="3-6 条最关键的发现,每条必须有数值证据",
    )
    caveats: List[str] = Field(
        default_factory=list,
        description="数据局限或方法警示(如样本不均、非正态),每条 <=60 字",
    )
    next_suggestions: List[str] = Field(
        default_factory=list,
        description="后续推荐:进一步分析、需要补充的数据等",
    )


class ReportSection(BaseModel):
    """报告中一节的结构化内容。"""
    title: str = Field(..., description="节标题")
    summary: str = Field(..., description="本节概要(<=200 字)", max_length=500)
    findings: List[StatFinding] = Field(default_factory=list, description="本节关键发现")


# ──────────────────────────────────────────────────────────────────
# 通用调用入口
# ──────────────────────────────────────────────────────────────────

_instructor_client: Optional[Any] = None


def _get_instructor():
    """惰性构造 instructor 包装的 DeepSeek 客户端,复用 _make_client 配置。"""
    global _instructor_client
    if _instructor_client is None:
        from app.agent import _make_client
        base_client = _make_client()
        # DeepSeek 不全面支持 JSON schema response_format,使用 MD_JSON 模式更稳
        _instructor_client = instructor.from_openai(
            base_client,
            mode=instructor.Mode.MD_JSON,
        )
    return _instructor_client


def structured_chat(
    response_model: Type[T],
    system: str,
    user: str,
    *,
    model: Optional[str] = None,
    max_retries: int = 2,
    temperature: float = 0.1,
) -> Optional[T]:
    """运行一次结构化 LLM 调用,失败返回 None(由调用方决定降级策略)。

    response_model: Pydantic 模型类,instructor 据此校验+重试
    system / user: 提示词
    max_retries: 解析失败的最大重试次数(instructor 内部循环)
    """
    try:
        client = _get_instructor()
    except Exception:
        return None

    try:
        return client.chat.completions.create(
            model=model or os.environ.get("STRUCTURED_MODEL", "deepseek-v4-pro"),
            response_model=response_model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            max_retries=max_retries,
            temperature=temperature,
            max_tokens=2000,
        )
    except Exception:
        return None
