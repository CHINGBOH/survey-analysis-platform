"""Generate docs/architecture.md — file tree + LoC + role + module imports.

Walks the project (skipping .git/data/output/node_modules/etc), groups files by
top-level directory with a hand-curated role description (looked up from
ROLE_MAP), and builds an import graph for app/ modules via ast.
"""
from __future__ import annotations

import ast
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import DOCS_DIR, md_table, rel, write_doc  # noqa: E402

SKIP_TOP = {".git", ".venv", "venv", "__pycache__", "node_modules",
            "output", "logs", ".pytest_cache", ".ruff_cache", ".ipynb_checkpoints"}
SKIP_NAMES = {".DS_Store"}

# Top-level role descriptions (kept tiny on purpose; not exhaustive function-level)
ROLE_MAP = {
    "app": "Streamlit UI + agent loop (DeepSeek function-calling) + tools",
    "01-clean": "Excel → SQLite ingestion (voucher cleaner + generic ingester)",
    "02-analyze": "R 统计分析模块（13 个，psych/car/lavaan/effsize 等）",
    "03-integrate": "结果汇编 (R)：跨模块结果整合为 Quarto 输入",
    "04-report": "Quarto 报告模板 + 渲染产物 (HTML/Word/PDF)",
    "agent": "Agent specs：system prompt、skills、subagents",
    "data": "数据：raw/ Excel 源、db/ SQLite 入库",
    "docs": "自动生成的技术文档（本目录）",
    "scripts": "构建脚本（docs 生成器等）",
    "00-explore": "Jupyter 数据探索 notebook",
}


def _count_lines(path: Path) -> int:
    try:
        return sum(1 for _ in path.open("rb"))
    except Exception:
        return 0


def _walk_dir(base: Path):
    files = []
    for path in sorted(base.rglob("*")):
        if not path.is_file():
            continue
        if any(p in SKIP_TOP for p in path.relative_to(ROOT).parts):
            continue
        if path.name in SKIP_NAMES:
            continue
        files.append(path)
    return files


def _imports_for(path: Path) -> set[str]:
    if path.suffix != ".py":
        return set()
    try:
        tree = ast.parse(path.read_text(errors="replace"))
    except SyntaxError:
        return set()
    out = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for n in node.names:
                out.add(n.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                out.add(node.module.split(".")[0])
    return out


def build_body() -> str:
    out = ["# 架构总览 (Architecture)\n",
           "三层管线: **Streamlit UI ⇄ Python Agent (tools) ⇄ R 统计脚本**。"
           "Agent 通过 OpenAI 函数调用 schema 编排 19 个工具，工具内 subprocess 调用 R 脚本，"
           "结果以 `.rds`/`.json` 写入 `output/results/`，再被 Quarto 渲染为报告。\n"]

    # Top-level directory roles
    out.append("\n## 顶层目录角色\n")
    top_dirs = sorted(p for p in ROOT.iterdir()
                      if p.is_dir() and p.name not in SKIP_TOP and not p.name.startswith("."))
    rows = []
    for d in top_dirs:
        files = _walk_dir(d)
        loc = sum(_count_lines(f) for f in files if f.suffix in {".py", ".R", ".md", ".sql", ".qmd"})
        rows.append([
            f"`{d.name}/`",
            ROLE_MAP.get(d.name, "(未注册角色)"),
            str(len(files)),
            f"{loc:,}",
        ])
    out.append(md_table(["目录", "角色", "文件数", "LoC (.py/.R/.md/.sql/.qmd)"], rows))

    # File listing per critical dir
    out.append("\n## 关键文件清单\n")
    for d_name in ["app", "01-clean", "02-analyze", "03-integrate", "04-report",
                   "agent", "scripts"]:
        d = ROOT / d_name
        if not d.exists():
            continue
        out.append(f"\n### `{d_name}/`\n")
        rows = []
        for f in _walk_dir(d):
            if f.suffix in {".pyc", ".rds", ".html", ".png", ".jpg"}:
                continue
            rows.append([
                f"`{rel(f)}`",
                f.suffix or "(no-ext)",
                str(_count_lines(f)),
            ])
        if rows:
            out.append(md_table(["路径", "类型", "行数"], rows))

    # Import graph for app/
    out.append("\n## `app/` 模块 import 图\n")
    out.append("内部依赖（仅显示对其他 `app.*` 模块的引用）:\n")
    app_dir = ROOT / "app"
    app_mods = {
        f.relative_to(ROOT).with_suffix("").as_posix().replace("/", ".")
        for f in app_dir.rglob("*.py") if f.name != "__init__.py"
    }
    rows = []
    for f in sorted(app_dir.rglob("*.py")):
        if f.name == "__init__.py":
            continue
        imps = _imports_for(f) & {"app"}
        # Also catch from app.X imports
        try:
            tree = ast.parse(f.read_text(errors="replace"))
            app_imps = set()
            for n in ast.walk(tree):
                if isinstance(n, ast.ImportFrom) and n.module and n.module.startswith("app"):
                    app_imps.add(n.module)
        except SyntaxError:
            app_imps = set()
        if app_imps:
            rows.append([f"`{rel(f)}`", ", ".join(f"`{m}`" for m in sorted(app_imps))])
    if rows:
        out.append(md_table(["模块", "import 的 app.* 模块"], rows))
    else:
        out.append("*(无内部依赖)*\n")

    return "\n".join(out)


def main():
    changed, path = write_doc(
        DOCS_DIR / "architecture.md",
        source="filesystem walk + ast import scan",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
