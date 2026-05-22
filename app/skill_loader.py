"""
app/skill_loader.py — 扫描 agent/skills/**/SKILL.md 与 agent/subagents/*.md
解析 YAML frontmatter (name / description),拼成精简目录注入系统提示。

设计原则:
- 不全文展开 skill — 否则上下文爆炸; 只给"目录 + 一句话描述"。
- 主 agent 看到目录后,可在需要时用 dispatch_subagent 工具去拉具体 skill 内容。
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "agent" / "skills"
SUBAGENTS_DIR = ROOT / "agent" / "subagents"

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


@dataclass
class SkillEntry:
    name: str
    description: str
    category: str  # eg "data-analysis", "workflow", "observability"
    path: Path


@dataclass
class SubagentEntry:
    name: str
    description: str
    model: str
    path: Path


def _parse_frontmatter(text: str) -> dict:
    """轻量级 YAML frontmatter 解析 — 只取 name / description / model 等单行键。
    避免引入 PyYAML 依赖; 复杂值(多行/列表)忽略。
    """
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return {}
    block = m.group(1)
    out: dict = {}
    current_key: Optional[str] = None
    for line in block.splitlines():
        if not line.strip():
            continue
        # 多行字符串延续(以空白开头)
        if line.startswith((" ", "\t")) and current_key:
            out[current_key] = (out.get(current_key, "") + " " + line.strip()).strip()
            continue
        if ":" in line:
            k, _, v = line.partition(":")
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            if v:
                out[k] = v
            current_key = k
    return out


def _short(text: str, max_len: int = 160) -> str:
    """单行化 + 截断,避免长描述污染系统提示。"""
    text = re.sub(r"\s+", " ", text or "").strip()
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"


def load_skills() -> List[SkillEntry]:
    if not SKILLS_DIR.exists():
        return []
    entries: List[SkillEntry] = []
    for skill_md in sorted(SKILLS_DIR.glob("*/*/SKILL.md")):
        try:
            meta = _parse_frontmatter(skill_md.read_text(encoding="utf-8"))
        except Exception:
            continue
        name = meta.get("name") or skill_md.parent.name
        desc = meta.get("description", "")
        category = skill_md.parent.parent.name
        entries.append(SkillEntry(name=name, description=desc, category=category, path=skill_md))
    return entries


def load_subagents() -> List[SubagentEntry]:
    if not SUBAGENTS_DIR.exists():
        return []
    entries: List[SubagentEntry] = []
    for md in sorted(SUBAGENTS_DIR.glob("*.md")):
        if md.name.lower() == "readme.md":
            continue
        try:
            meta = _parse_frontmatter(md.read_text(encoding="utf-8"))
        except Exception:
            continue
        name = meta.get("name") or md.stem
        desc = meta.get("description", "")
        model = meta.get("model", "default")
        entries.append(SubagentEntry(name=name, description=desc, model=model, path=md))
    return entries


def build_catalogue_block() -> str:
    """生成可直接拼接到 system_prompt 的目录段(中文 + Markdown 表格)。"""
    skills = load_skills()
    subagents = load_subagents()

    lines: List[str] = []
    if skills:
        lines.append("\n## 可用 Skill 目录(按需要时让用户/你自己引用)\n")
        lines.append("> 这是知识/方法论库,不是工具。需要详细做法时,可在回答中引用 skill 名,或通过 `dispatch_subagent` 让子 agent 加载完整内容执行。\n")
        # 按 category 分组
        by_cat: dict = {}
        for s in skills:
            by_cat.setdefault(s.category, []).append(s)
        for cat, items in sorted(by_cat.items()):
            lines.append(f"\n**{cat}**")
            for s in items:
                lines.append(f"- `{s.name}` — {_short(s.description)}")

    if subagents:
        lines.append("\n\n## 可调度 Subagent 角色")
        lines.append("> 通过 `dispatch_subagent(role, task)` 工具把专项任务委派给具备特定专长的子 agent。\n")
        for sa in subagents:
            lines.append(f"- `{sa.name}` ({sa.model}) — {_short(sa.description)}")

    lines.append("")
    return "\n".join(lines)


def load_skill_content(name: str) -> Optional[str]:
    """按 skill 名加载完整 SKILL.md 内容(供 dispatch_subagent 拼上下文)。"""
    for s in load_skills():
        if s.name == name:
            return s.path.read_text(encoding="utf-8")
    return None


def load_subagent_content(name: str) -> Optional[str]:
    for sa in load_subagents():
        if sa.name == name:
            return sa.path.read_text(encoding="utf-8")
    return None


if __name__ == "__main__":
    print(build_catalogue_block())
