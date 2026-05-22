from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, Optional


class PipelineStage(str, Enum):
    IDLE = "idle"
    UPLOADED = "uploaded"
    CLEANING = "cleaning"
    ANALYZING = "analyzing"
    COMPILING = "compiling"
    REPORTING = "reporting"
    DONE = "done"


class ModuleStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    DONE = "done"
    ERROR = "error"


ALL_MODULES = [
    "descriptives", "crosstabs", "ttest", "anova", "correlation",
    "reliability", "factor_analysis", "regression",
    "mediation", "moderation", "cluster", "power_bootstrap",
]

MODULE_LABELS_CN = {
    "descriptives": "描述统计",
    "crosstabs": "交叉表分析",
    "ttest": "t检验",
    "anova": "方差分析",
    "correlation": "相关分析",
    "reliability": "信度分析",
    "factor_analysis": "因子分析",
    "regression": "回归分析",
    "mediation": "中介效应",
    "moderation": "调节效应",
    "cluster": "聚类分析",
    "power_bootstrap": "Bootstrap效力",
}

STATUS_ICONS = {
    ModuleStatus.PENDING: "⬜",
    ModuleStatus.RUNNING: "🔄",
    ModuleStatus.DONE: "✅",
    ModuleStatus.ERROR: "❌",
}

STAGE_LABELS_CN = {
    PipelineStage.IDLE: "等待上传",
    PipelineStage.UPLOADED: "文件已上传",
    PipelineStage.CLEANING: "数据清洗中",
    PipelineStage.ANALYZING: "统计分析中",
    PipelineStage.COMPILING: "整合结果中",
    PipelineStage.REPORTING: "生成报告中",
    PipelineStage.DONE: "分析完成",
}


@dataclass
class AppState:
    stage: PipelineStage = PipelineStage.IDLE
    uploaded_path: Optional[str] = None
    uploaded_filename: Optional[str] = None
    module_statuses: Dict[str, ModuleStatus] = field(
        default_factory=lambda: {m: ModuleStatus.PENDING for m in ALL_MODULES}
    )
    report_path: Optional[str] = None
    clean_done: bool = False
    plan: Optional[dict] = None  # active AnalysisPlan manifest (surveys/modules/compare/focus)

    def set_module(self, module: str, status: ModuleStatus):
        self.module_statuses[module] = status

    def done_modules(self):
        return [m for m, s in self.module_statuses.items() if s == ModuleStatus.DONE]

    def all_done(self):
        return all(s == ModuleStatus.DONE for s in self.module_statuses.values())
