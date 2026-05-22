"""
app/requirements_schema.py — Structured analysis plan.

The agent reads the user's natural-language intent and emits an AnalysisPlan.
Pydantic VALIDATES the plan before anything runs — this is where software
filters LLM hallucination: an invalid survey name or made-up module is
rejected before a single R script executes.
"""
from datetime import date

from pydantic import BaseModel, Field, model_validator

VALID_SURVEYS = ["survey1", "survey2"]
ALL_MODULES = [
    "descriptives", "crosstabs", "ttest", "anova", "correlation",
    "reliability", "factor_analysis", "regression",
    "mediation", "moderation", "cluster", "power_bootstrap",
    "survey_specific",
]


class AnalysisPlan(BaseModel):
    surveys: list[str] = Field(..., description="要分析的调查，survey1 和/或 survey2")
    modules: list[str] = Field(..., description="要运行的分析模块，或 ['all'] 表示全部")
    compare: bool = Field(False, description="是否对两个调查做对比分析")
    focus: str = Field("", description="核心研究问题（自然语言）")

    @model_validator(mode="after")
    def _validate(self):
        # surveys
        if not self.surveys:
            raise ValueError("至少选择一个调查")
        invalid_s = [s for s in self.surveys if s not in VALID_SURVEYS]
        if invalid_s:
            raise ValueError(f"未知调查: {invalid_s}，只能是 {VALID_SURVEYS}")
        self.surveys = list(dict.fromkeys(self.surveys))  # dedupe, keep order

        # modules — expand "all"
        if not self.modules:
            raise ValueError("至少选择一个模块")
        if any(m.lower() == "all" for m in self.modules):
            self.modules = list(ALL_MODULES)
        else:
            invalid_m = [m for m in self.modules if m not in ALL_MODULES]
            if invalid_m:
                raise ValueError(f"未知模块: {invalid_m}")
            # keep canonical order, dedupe
            self.modules = [m for m in ALL_MODULES if m in set(self.modules)]

        # compare implies both surveys
        if self.compare:
            self.surveys = list(VALID_SURVEYS)

        return self

    def to_manifest(self) -> dict:
        d = self.model_dump()
        d["generated"] = date.today().isoformat()
        return d
