"""
app/requirements_schema.py — Structured analysis plan.

The agent reads the user's natural-language intent and emits an AnalysisPlan.
Pydantic VALIDATES the plan before anything runs — this is where software
filters LLM hallucination: an invalid survey name or made-up module is
rejected before a single R script executes.
"""
from datetime import date

from pydantic import BaseModel, Field, model_validator

from app.state import ALL_MODULES
from app.surveys import is_valid_survey_id, list_surveys


class AnalysisPlan(BaseModel):
    surveys: list[str] = Field(..., description="要分析的 survey_id 列表(每个对应一个已上传文件)")
    modules: list[str] = Field(..., description="要运行的分析模块，或 ['all'] 表示全部")
    compare: bool = Field(False, description="是否做多组对比(需 ≥2 个 survey)")
    focus: str = Field("", description="核心研究问题（自然语言）")

    @model_validator(mode="after")
    def _validate(self):
        if not self.surveys:
            raise ValueError("至少选择一个调查")
        bad = [s for s in self.surveys if not is_valid_survey_id(s)]
        if bad:
            raise ValueError(f"survey_id 非法(只能字母数字下划线/中文,≤48 字符): {bad}")
        # 不强制要求已落库 — set_plan 时可能还没清洗,清洗时再验真
        self.surveys = list(dict.fromkeys(self.surveys))  # dedupe, keep order

        if not self.modules:
            raise ValueError("至少选择一个模块")
        if any(m.lower() == "all" for m in self.modules):
            self.modules = list(ALL_MODULES)
        else:
            invalid_m = [m for m in self.modules if m not in ALL_MODULES]
            if invalid_m:
                raise ValueError(f"未知模块: {invalid_m}")
            self.modules = [m for m in ALL_MODULES if m in set(self.modules)]

        if self.compare and len(self.surveys) < 2:
            # compare=True 但只给了 1 个 survey → 自动尝试补一个已存在的
            existing = [s for s in list_surveys() if s not in self.surveys]
            if existing:
                self.surveys.append(existing[0])
            else:
                raise ValueError("compare=True 需要 ≥2 个 survey,但当前只有一个可用")

        return self

    def to_manifest(self) -> dict:
        d = self.model_dump()
        d["generated"] = date.today().isoformat()
        return d
