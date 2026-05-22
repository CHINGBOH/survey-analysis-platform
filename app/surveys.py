"""
app/surveys.py — 动态 survey 发现 (唯一真源)。

替代历史上散落 25+ 处的 `["survey1","survey2"]` 硬编码。
规则:
- 仓库默认 schema: voucher 问卷,自带 survey1/survey2 模板槽 (保留兼容)
- 用户上传任意文件 → 文件名 slugify 派生 survey_id,落库为 data/db/<sid>.db
- 任何调用方需要"有哪些 survey?",问这里。
"""
from __future__ import annotations

import re
import unicodedata
from pathlib import Path
from typing import List, Optional

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "data" / "db"
RAW_DIR = ROOT / "data" / "raw"

# Voucher 模板保留槽:存在历史 clean_to_sqlite.py 的硬编码 schema,允许 LLM 使用
_TEMPLATE_SLOTS = ["survey1", "survey2"]


def _slugify(name: str) -> str:
    """文件名 → 合法 survey_id (字母数字下划线,小写)。"""
    stem = Path(name).stem
    stem = unicodedata.normalize("NFKC", stem)
    stem = re.sub(r"[^\w\u4e00-\u9fff]+", "_", stem, flags=re.UNICODE).strip("_")
    stem = stem.lower()
    if not stem or not re.match(r"^[a-z0-9_\u4e00-\u9fff]", stem):
        stem = f"survey_{stem}" if stem else "survey_upload"
    return stem[:48]


def derive_survey_id(filename: str) -> str:
    """从上传文件名派生唯一 survey_id。voucher 默认两份保留映射。"""
    if not filename:
        return "survey1"
    # 兼容现网:voucher 默认两个文件名继续走 survey1/survey2
    base = Path(filename).name
    if "完整版" in base or "209" in base:
        return "survey1"
    if "精简版" in base or "206" in base:
        return "survey2"
    return _slugify(base)


def list_surveys() -> List[str]:
    """列出当前真正可用的 survey_id。
    优先级:已落库 (data/db/*.db) > raw 文件派生 > 模板槽。
    返回去重后的有序列表。
    """
    seen: List[str] = []

    def _add(sid: str):
        if sid and sid not in seen:
            seen.append(sid)

    if DB_DIR.exists():
        for db in sorted(DB_DIR.glob("*.db")):
            _add(db.stem)
    if RAW_DIR.exists():
        for f in sorted(list(RAW_DIR.glob("*.xlsx")) + list(RAW_DIR.glob("*.csv"))):
            _add(derive_survey_id(f.name))
    for s in _TEMPLATE_SLOTS:
        _add(s)
    return seen


def default_survey() -> Optional[str]:
    """当前默认 survey: 最新修改的 db 文件,fallback 到第一个可用。"""
    if DB_DIR.exists():
        dbs = sorted(DB_DIR.glob("*.db"), key=lambda p: p.stat().st_mtime, reverse=True)
        if dbs:
            return dbs[0].stem
    surveys = list_surveys()
    return surveys[0] if surveys else None


def survey_suffix(survey_id: str) -> str:
    """report/charts 文件后缀。历史 survey1→s1 / survey2→s2 保留;其他直接用 id。"""
    if survey_id == "survey1":
        return "s1"
    if survey_id == "survey2":
        return "s2"
    return survey_id


def is_valid_survey_id(survey_id: str) -> bool:
    """合法性:字母数字下划线,且 ≤ 48 字符。不要求已存在(set_plan 时还没清洗)。"""
    return bool(survey_id and re.match(r"^[\w\u4e00-\u9fff]{1,48}$", survey_id))
