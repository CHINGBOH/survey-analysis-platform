"""Generate docs/reference/skills.md from agent/skills/**/SKILL.md."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, md_table, rel, write_doc  # noqa: E402

PROJECT_SKILLS = ROOT / "agent" / "skills"
USER_SKILLS = Path.home() / ".copilot" / "skills"

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def parse_frontmatter(text: str) -> dict:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    data: dict = {}
    key = None
    buf: list[str] = []

    def flush():
        if key is not None:
            data[key] = "\n".join(buf).strip()

    for line in m.group(1).splitlines():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s*:", line):
            flush()
            k, _, v = line.partition(":")
            key = k.strip()
            buf = [v.strip().strip('"').strip("'")]
        else:
            buf.append(line.strip())
    flush()
    return data


def collect(base: Path) -> list[tuple[str, dict, Path]]:
    rows = []
    if not base.exists():
        return rows
    for skill in sorted(base.rglob("SKILL.md")):
        try:
            fm = parse_frontmatter(skill.read_text(errors="replace"))
        except Exception as e:
            fm = {"name": skill.parent.name, "description": f"(parse error: {e})"}
        name = fm.get("name") or skill.parent.name
        parts = skill.relative_to(base).parts
        category = parts[0] if len(parts) > 1 else "(root)"
        fm["_category"] = category
        rows.append((name, fm, skill))
    return rows


def build_body() -> str:
    project = collect(PROJECT_SKILLS)
    user = collect(USER_SKILLS)

    out = ["# 技能参考 (Skills Reference)\n"]
    out.append(f"项目技能 **{len(project)}** 个 (`agent/skills/`) + 用户技能 **{len(user)}** 个 (`~/.copilot/skills/`)。\n")
    out.append("技能由 `app/skill_loader.py` 自动发现并注入 system prompt。改 SKILL.md frontmatter 后下次对话即生效（无需重启）。\n")

    def render(title: str, rows: list, base: Path):
        if not rows:
            return
        out.append(f"\n## {title}\n")
        by_cat: dict[str, list] = {}
        for name, fm, path in rows:
            by_cat.setdefault(fm.get("_category", "(root)"), []).append((name, fm, path))
        for cat in sorted(by_cat):
            out.append(f"\n### `{cat}/`\n")
            table_rows = []
            for name, fm, path in sorted(by_cat[cat]):
                try:
                    src_path = rel(path)
                except Exception:
                    src_path = str(path)
                table_rows.append([
                    f"`{name}`",
                    fm.get("description", ""),
                    fm.get("when_to_use", "")[:140],
                    f"`{src_path}`",
                ])
            out.append(md_table(["name", "description", "when_to_use", "source"], table_rows))
    render("项目技能 (随仓库版本管理)", project, PROJECT_SKILLS)
    render("用户技能 (本机全局)", user, USER_SKILLS)
    return "\n".join(out)


def main():
    changed, path = write_doc(
        REF_DIR / "skills.md",
        source="agent/skills/**/SKILL.md + ~/.copilot/skills/**/SKILL.md (YAML frontmatter)",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
