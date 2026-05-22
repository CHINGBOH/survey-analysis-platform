"""Generate docs/reference/tools.md from app/agent.py:TOOL_DEFS."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, md_table, write_doc  # noqa: E402


def _param_rows(params: dict) -> list[list[str]]:
    props = (params or {}).get("properties", {}) or {}
    required = set((params or {}).get("required", []) or [])
    rows = []
    for name, schema in props.items():
        typ = schema.get("type", "")
        if "enum" in schema:
            typ += " (enum: " + ", ".join(map(str, schema["enum"])) + ")"
        rows.append([
            f"`{name}`",
            typ,
            "✓" if name in required else "",
            (schema.get("description") or "").strip(),
        ])
    return rows


def build_body() -> str:
    from app.agent import TOOL_DEFS

    out = ["# 工具参考 (Tools Reference)\n",
           f"共 **{len(TOOL_DEFS)}** 个工具，按 `app/agent.py:TOOL_DEFS` 注册顺序排列。\n"]

    out.append("## 索引\n")
    for t in TOOL_DEFS:
        n = t["function"]["name"]
        anchor = n.lower().replace("_", "-")
        out.append(f"- [`{n}`](#{anchor})")
    out.append("")

    for t in TOOL_DEFS:
        fn = t["function"]
        name = fn["name"]
        desc = (fn.get("description") or "").strip()
        out.append(f"\n## `{name}`\n")
        out.append(f"{desc}\n")
        params = fn.get("parameters", {})
        rows = _param_rows(params)
        if rows:
            out.append("**参数**\n")
            out.append(md_table(["参数", "类型", "必填", "描述"], rows))
        else:
            out.append("**参数**: 无\n")
        out.append(f"实现: [`app/tools.py`](../../app/tools.py) 搜索函数名 `{name}`\n")
    return "\n".join(out)


def main():
    changed, path = write_doc(
        REF_DIR / "tools.md",
        source="app/agent.py:TOOL_DEFS (function-calling JSON schemas)",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
